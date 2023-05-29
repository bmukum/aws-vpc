data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  public_subnet_tags = merge({
    public = "true"
    app    = "false"
    db     = "false"
  }, var.public_subnet_tags)

  app_subnet_tags = merge({
    public = "false"
    app    = "true"
    db     = "false"
  }, var.app_subnet_tags)

  db_subnet_tags = merge({
    public = "false"
    app    = "false"
    db     = "true"
  }, var.db_subnet_tags)

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]

  interface_endpoints = length(var.interface_services) == 0 ? ["com.amazonaws.${var.region}.s3", "com.amazonaws.${var.region}.lambda"] : concat(["com.amazonaws.${var.region}.s3", "com.amazonaws.${var.region}.lambda"], var.interface_services)
  gateway_endpoints   = length(var.gateway_services) == 0 ? ["com.amazonaws.${var.region}.dynamodb"] : concat(["com.amazonaws.${var.region}.dynamodb"], var.gateway_services)
}


/**
 * VPC
 */
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = "true"

  tags = merge(var.tags, {
    Name = var.name
  })
}

/**
 * Elastic IP/EIP
 */
resource "aws_eip" "ngw" {
  vpc   = true
  count = var.az_count
}

/**
 * Gateways
 */
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_nat_gateway" "ngw" {
  count = var.create_single_natgateway ? 1 : var.az_count

  allocation_id = element(aws_eip.ngw.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(var.tags, {
    Name = format("%s-natgw-%02d", var.name, count.index)
  })
}

/**
 * Route tables
 */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  count  = var.az_count

  tags = merge(var.tags, {
    Name = format("%s-priv-%02d", var.name, count.index)
  })
}

resource "aws_route" "private" {
  count                  = var.az_count
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
}

//public subnet
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = true

  tags = merge(var.tags, local.public_subnet_tags, {
    Name = format("%s-public%02d", var.name, count.index)
    az   = element(local.azs, count.index)
  })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "db" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 4 + count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = false

  tags = merge(var.tags, local.db_subnet_tags, {
    Name = format("%s-db%02d", var.name, count.index)
    az   = element(local.azs, count.index)
  })
}

resource "aws_route_table_association" "private_db" {
  count = var.az_count

  subnet_id      = element(aws_subnet.db.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

/**
 * App
 */
resource "aws_subnet" "app" {
  count = var.az_count

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, 4 + count.index)
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = false

  tags = merge(var.tags, local.app_subnet_tags, {
    Name = format("%s-app%02d", var.name, count.index)
    az   = element(local.azs, count.index)
  })
}

resource "aws_route_table_association" "private_app" {
  count = var.az_count

  subnet_id      = element(aws_subnet.app.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_flow_log" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  log_destination = aws_cloudwatch_log_group.log_group[0].arn
  iam_role_arn    = aws_iam_role.vpc_flow_log_cloudwatch[0].arn
  vpc_id          = aws_vpc.vpc.id
  traffic_type    = "ALL"

  tags = var.tags
}



resource "aws_cloudwatch_log_group" "log_group" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "${var.name}-log-group"
  retention_in_days = var.log_retention
  kms_key_id        = aws_kms_key.key.arn
  tags              = var.tags
}

resource "aws_iam_role" "vpc_flow_log_cloudwatch" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "${var.name}-flow-log"
  assume_role_policy = data.aws_iam_policy_document.flow_log_cloudwatch_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flow_log_cloudwatch_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    effect = "Allow"

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_cloudwatch" {
  count      = var.enable_flow_logs ? 1 : 0
  role       = aws_iam_role.vpc_flow_log_cloudwatch[0].name
  policy_arn = aws_iam_policy.vpc_flow_log_cloudwatch[0].arn
}

resource "aws_iam_policy" "vpc_flow_log_cloudwatch" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "${var.name}-flow-log"
  policy = data.aws_iam_policy_document.vpc_flow_log_cloudwatch.json
  tags   = var.tags
}

data "aws_iam_policy_document" "vpc_flow_log_cloudwatch" {
  statement {
    sid = "AWSVPCFlowLogsPushToCloudWatch"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each          = toset(local.interface_endpoints)
  service_name      = each.key
  subnet_ids        = aws_subnet.app.*.id
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.vpc.id
  timeouts {
    create = "20m"
    delete = "20m"
  }
  tags = var.tags
}

resource "aws_vpc_endpoint" "gateway_endpoints" {
  for_each          = toset(local.gateway_endpoints)
  service_name      = each.key
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.vpc.id
  timeouts {
    create = "20m"
    delete = "20m"
  }
  tags = var.tags
}

//policy data for kms key
data "aws_iam_policy_document" "kms_cloudwatch" {
  statement {
    sid    = "allowIamRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "kmsEncryptCloudWatch"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_alias" "alias" {
  name          = "alias/${var.name}-cloudwatch"
  target_key_id = aws_kms_key.key.key_id
}

resource "aws_kms_key" "key" {
  description             = "KMS to encrypt cloudwatch logs"
  deletion_window_in_days = 10
  policy                  = data.aws_iam_policy_document.kms_cloudwatch.json
}