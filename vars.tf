variable "name" {
  description = "Name of this VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for this VPC"
  type        = string
}

variable "az_count" {
  description = "The number of AZs to launch this VPC in"
  type        = number
  default     = 3
}

variable "region" {
  description = "Region to deploy this VPC"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Optionally specify additional tags to add to the VPC. Please reference the [AWS Implementation Guide](https://security.rvdocs.io/guides/aws-implementation.html#required-tags) for more details on what tags are required"
  default     = {}
}

variable "app_subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Optional map of extra tags for app subnets."
}

variable "public_subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Optional map of extra tags for public subnets."
}

variable "db_subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Optional map of extra for db tags subnets."
}

variable "enable_flow_logs" {
  description = "If true, flow logs to CloudWatch will be enabled for the created VPC"
  type        = bool
  default     = true
}

variable "log_retention" {
  type        = number
  description = "The time in days to retain flow logs. If this is set to 0 the logs will be retained indefinitely."
  default     = 30
}

variable "gateway_services" {
  type        = list(string)
  description = "List of AWS services to configure gateway vpc endpoints. This should exclude dynamodb."
  default     = []
}

variable "interface_services" {
  type        = list(string)
  description = "List of AWS services to configure interface vpc endpoints. This should exclude s3 and lambda."
  default     = []
}

variable "create_single_natgateway" {
  type        = bool
  description = "True if you want only a single nat gateway created"
  default     = false
}