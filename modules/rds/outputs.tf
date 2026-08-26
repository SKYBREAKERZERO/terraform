# ============================================================
# DB Instance
# ============================================================

output "db_instance_id" {
  description = "RDS DB instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_identifier" {
  description = "RDS DB instance identifier"
  value       = aws_db_instance.this.identifier
}

output "db_instance_arn" {
  description = "ARN of the RDS DB instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_status" {
  description = "Current status of the RDS DB instance"
  value       = aws_db_instance.this.status
}


# ============================================================
# Endpoint
# ============================================================

output "db_endpoint" {
  description = "Connection endpoint of the RDS DB instance"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "DNS address of the RDS DB instance"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Database listener port"
  value       = aws_db_instance.this.port
}


# ============================================================
# Database
# ============================================================

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.this.db_name
}

output "engine" {
  description = "Database engine"
  value       = aws_db_instance.this.engine
}

output "engine_version" {
  description = "Database engine version"
  value       = aws_db_instance.this.engine_version_actual
}

output "instance_class" {
  description = "RDS DB instance class"
  value       = aws_db_instance.this.instance_class
}


# ============================================================
# Network
# ============================================================

output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group"
  value       = aws_db_subnet_group.this.name
}

output "db_subnet_group_arn" {
  description = "ARN of the RDS DB subnet group"
  value       = aws_db_subnet_group.this.arn
}

output "vpc_security_group_ids" {
  description = "Security group IDs attached to the RDS DB instance"
  value       = aws_db_instance.this.vpc_security_group_ids
}

output "availability_zone" {
  description = "Availability Zone of the RDS DB instance"
  value       = aws_db_instance.this.availability_zone
}


# ============================================================
# Availability / Storage
# ============================================================

output "multi_az" {
  description = "Whether Multi-AZ is enabled"
  value       = aws_db_instance.this.multi_az
}

output "storage_encrypted" {
  description = "Whether storage encryption is enabled"
  value       = aws_db_instance.this.storage_encrypted
}

output "storage_type" {
  description = "RDS storage type"
  value       = aws_db_instance.this.storage_type
}

output "allocated_storage" {
  description = "Allocated storage in GiB"
  value       = aws_db_instance.this.allocated_storage
}


# ============================================================
# Protection / Backup
# ============================================================

output "backup_retention_period" {
  description = "Automated backup retention period in days"
  value       = aws_db_instance.this.backup_retention_period
}

output "deletion_protection" {
  description = "Whether deletion protection is enabled"
  value       = aws_db_instance.this.deletion_protection
}

output "publicly_accessible" {
  description = "Whether the RDS DB instance is publicly accessible"
  value       = aws_db_instance.this.publicly_accessible
}