output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "The VPC id"
}

output "vpc_cidr" {
  value       = aws_vpc.vpc.cidr_block
  description = "CIDR block of the VPC"
}

output "public_subnet_cidrs" {
  value       = aws_subnet.public.*.cidr_block
  description = "Public subnet cidrs"
}

output "public_subnet_ids" {
  value       = aws_subnet.public.*.id
  description = "Public subnet ids"
}

output "app_subnet_cidrs" {
  value       = aws_subnet.app.*.cidr_block
  description = "Private subnet cidrs"
}

output "app_subnet_ids" {
  value       = aws_subnet.app.*.id
  description = "Private subnet ids"
}

output "db_subnet_cidrs" {
  value       = aws_subnet.db.*.cidr_block
  description = "Database subnet cidrs"
}

output "db_subnet_ids" {
  value       = aws_subnet.db.*.id
  description = "Database subnet ids"
}

output "nat_gateway_public_ips" {
  value       = aws_nat_gateway.ngw.*.public_ip
  description = "IP address of the nat gateway"
}