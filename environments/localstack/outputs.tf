# ============================================================
# Network Outputs
# ============================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value       = module.network.private_db_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.network.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.network.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT Gateways"
  value       = module.network.nat_gateway_public_ips
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.network.public_route_table_id
}

output "private_app_route_table_ids" {
  description = "IDs of the private application route tables"
  value       = module.network.private_app_route_table_ids
}

output "private_db_route_table_ids" {
  description = "IDs of the private database route tables"
  value       = module.network.private_db_route_table_ids
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC Endpoint"
  value       = module.network.s3_vpc_endpoint_id
}


# ============================================================
# Security Outputs
# ============================================================

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.security.app_security_group_id
}

output "app_security_group_arn" {
  description = "ARN of the application security group"
  value       = module.security.app_security_group_arn
}

output "app_security_group_name" {
  description = "Name of the application security group"
  value       = module.security.app_security_group_name
}


# ============================================================
# IAM Outputs
# ============================================================

output "ec2_role_name" {
  description = "Name of the EC2 IAM role"
  value       = module.iam.ec2_role_name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = module.iam.ec2_role_arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 IAM instance profile"
  value       = module.iam.ec2_instance_profile_name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 IAM instance profile"
  value       = module.iam.ec2_instance_profile_arn
}

output "ssm_policy_arn" {
  description = "ARN of the EC2 SSM policy when enabled"
  value       = module.iam.ssm_policy_arn
}

output "cloudwatch_agent_policy_arn" {
  description = "ARN of the CloudWatch Agent policy when enabled"
  value       = module.iam.cloudwatch_agent_policy_arn
}


# ============================================================
# EC2 Outputs
# ============================================================

output "ec2_instance_ids" {
  description = "Map of application EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "ec2_instance_arns" {
  description = "Map of application EC2 instance ARNs"
  value       = module.ec2.instance_arns
}

output "ec2_private_ips" {
  description = "Map of application EC2 private IP addresses"
  value       = module.ec2.private_ips
}

output "ec2_public_ips" {
  description = "Map of application EC2 public IP addresses"
  value       = module.ec2.public_ips
}

output "ec2_availability_zones" {
  description = "Map of application EC2 availability zones"
  value       = module.ec2.availability_zones
}

output "ec2_instance_states" {
  description = "Map of application EC2 instance states"
  value       = module.ec2.instance_states
}

output "ec2_primary_network_interface_ids" {
  description = "Map of application EC2 primary network interface IDs"
  value       = module.ec2.primary_network_interface_ids
}

output "ec2_subnet_ids" {
  description = "Map of subnet IDs used by application EC2 instances"
  value       = module.ec2.subnet_ids
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.s3.bucket_id
}

output "s3_bucket_name" {
  description = "Name of the LocalStack S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the LocalStack S3 bucket"
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the LocalStack S3 bucket"
  value       = module.s3.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the LocalStack S3 bucket"
  value       = module.s3.bucket_regional_domain_name
}

output "s3_versioning_status" {
  description = "Versioning status of the LocalStack S3 bucket"
  value       = module.s3.versioning_status
}

output "s3_encryption_algorithm" {
  description = "Configured server-side encryption algorithm of the LocalStack S3 bucket"
  value       = module.s3.encryption_algorithm
}

output "s3_kms_key_arn" {
  description = "KMS key ARN used by the LocalStack S3 bucket when SSE-KMS is enabled"
  value       = module.s3.kms_key_arn
}

output "s3_bucket_key_enabled" {
  description = "Whether S3 Bucket Key is effectively enabled"
  value       = module.s3.bucket_key_enabled
}

output "s3_public_access_block_enabled" {
  description = "Whether all public access protections are enabled"
  value       = module.s3.public_access_block_enabled
}

output "s3_lifecycle_enabled" {
  description = "Whether S3 lifecycle management is configured to be enabled"
  value       = module.s3.lifecycle_enabled
}