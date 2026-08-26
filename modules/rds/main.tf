# ============================================================
# DB Subnet Group
# ============================================================

resource "aws_db_subnet_group" "this" {
  name = "${var.project_name}-${var.environment}-db-subnet-group"

  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-${var.environment}-db-subnet-group"
      Component = "database"
      Service   = "rds"
      Tier      = "private-db"
    }
  )
}


# ============================================================
# RDS Instance
# ============================================================

resource "aws_db_instance" "this" {
  identifier = var.db_identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  port = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  publicly_accessible = var.publicly_accessible
  multi_az            = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted ? var.kms_key_id : null

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = (
    var.skip_final_snapshot
    ? null
    : var.final_snapshot_identifier
  )

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately           = var.apply_immediately

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = (
    var.monitoring_interval > 0
    ? var.monitoring_role_arn
    : null
  )

  performance_insights_enabled = var.performance_insights_enabled

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  copy_tags_to_snapshot = true

  tags = merge(
    var.common_tags,
    {
      Name      = var.db_identifier
      Component = "database"
      Service   = "rds"
      Role      = "primary"
      Tier      = "private-db"
    }
  )
}