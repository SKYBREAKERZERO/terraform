# ============================================================
# VPC
# ============================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}


# ============================================================
# Public Subnets
# ============================================================

output "public_subnet_ids" {
  description = "Map of public subnet IDs"

  value = {
    for key, subnet in aws_subnet.public :
    key => subnet.id
  }
}


# ============================================================
# Private Application Subnets
# ============================================================

output "private_app_subnet_ids" {
  description = "Map of private application subnet IDs"

  value = {
    for key, subnet in aws_subnet.private_app :
    key => subnet.id
  }
}


# ============================================================
# Private Database Subnets
# ============================================================

output "private_db_subnet_ids" {
  description = "Map of private database subnet IDs"

  value = {
    for key, subnet in aws_subnet.private_db :
    key => subnet.id
  }
}


# ============================================================
# Internet Gateway
# ============================================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.create_internet_gateway ? aws_internet_gateway.this[0].id : null
}


# ============================================================
# NAT Gateways
# ============================================================

output "nat_gateway_ids" {
  description = "Map of NAT Gateway IDs"

  value = {
    for key, nat_gateway in aws_nat_gateway.this :
    key => nat_gateway.id
  }
}

output "nat_gateway_public_ips" {
  description = "Map of NAT Gateway public IP addresses"

  value = {
    for key, eip in aws_eip.nat :
    key => eip.public_ip
  }
}


# ============================================================
# Public Route Table
# ============================================================

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}


# ============================================================
# Private Application Route Tables
# ============================================================

output "private_app_route_table_ids" {
  description = "Map of private application route table IDs"

  value = {
    for key, route_table in aws_route_table.private_app :
    key => route_table.id
  }
}


# ============================================================
# Private Database Route Tables
# ============================================================

output "private_db_route_table_ids" {
  description = "Map of private database route table IDs"

  value = {
    for key, route_table in aws_route_table.private_db :
    key => route_table.id
  }
}


# ============================================================
# VPC Endpoints
# ============================================================

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}