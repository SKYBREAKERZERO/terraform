# ============================================================
# RDS
# ============================================================

variable "rds_engine" {
  description = "RDS database engine."
  type        = string
  default     = "mysql"

  validation {
    condition = contains(
      [
        "mysql",
        "postgres"
      ],
      var.rds_engine
    )

    error_message = "rds_engine must be mysql or postgres."
  }
}

variable "rds_engine_version" {
  description = "Optional RDS engine version."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_instance_class" {
  description = "RDS DB instance class."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = length(trimspace(var.rds_instance_class)) > 0
    error_message = "rds_instance_class must not be empty."
  }
}

variable "rds_database_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"

  validation {
    condition     = length(trimspace(var.rds_database_name)) > 0
    error_message = "rds_database_name must not be empty."
  }
}

variable "rds_master_username" {
  description = "RDS master username."
  type        = string
  default     = "admin"

  validation {
    condition     = length(trimspace(var.rds_master_username)) > 0
    error_message = "rds_master_username must not be empty."
  }
}

variable "rds_master_password" {
  description = "RDS master password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.rds_master_password) >= 8
    error_message = "rds_master_password must contain at least 8 characters."
  }
}

# ============================================================
# RDS - Availability
# ============================================================

variable "rds_multi_az" {
  description = "Whether RDS Multi-AZ deployment is enabled."
  type        = bool
  default     = false
}

# ============================================================
# RDS - Storage
# ============================================================

variable "rds_allocated_storage" {
  description = "Initial RDS storage size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.rds_allocated_storage >= 20
    error_message = "rds_allocated_storage must be at least 20 GiB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum autoscaled RDS storage size in GiB. Set to 0 to disable autoscaling."
  type        = number
  default     = 0

  validation {
    condition = (
      var.rds_max_allocated_storage == 0 ||
      var.rds_max_allocated_storage >= var.rds_allocated_storage
    )

    error_message = "rds_max_allocated_storage must be 0 or greater than or equal to rds_allocated_storage."
  }
}

variable "rds_storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "gp3"

  validation {
    condition = contains(
      [
        "gp2",
        "gp3",
        "io1",
        "io2"
      ],
      var.rds_storage_type
    )

    error_message = "rds_storage_type must be gp2, gp3, io1, or io2."
  }
}

variable "rds_storage_encrypted" {
  description = "Whether RDS storage encryption is enabled."
  type        = bool
  default     = true
}

variable "rds_kms_key_id" {
  description = "Optional KMS key ID or ARN for RDS storage encryption."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# RDS - Backup
# ============================================================

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention period in days."
  type        = number
  default     = 7

  validation {
    condition = (
      var.rds_backup_retention_period >= 0 &&
      var.rds_backup_retention_period <= 35
    )

    error_message = "rds_backup_retention_period must be between 0 and 35 days."
  }
}

variable "rds_backup_window" {
  description = "Preferred RDS backup window."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_maintenance_window" {
  description = "Preferred RDS maintenance window."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# RDS - Protection / Snapshot
# ============================================================

variable "rds_deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Whether the final DB snapshot is skipped during deletion."
  type        = bool
  default     = true
}

variable "rds_final_snapshot_identifier" {
  description = "Final DB snapshot identifier when final snapshot creation is enabled."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# RDS - Maintenance / Upgrade
# ============================================================

variable "rds_auto_minor_version_upgrade" {
  description = "Whether minor engine upgrades are automatically applied."
  type        = bool
  default     = true
}

variable "rds_apply_immediately" {
  description = "Whether database modifications are applied immediately."
  type        = bool
  default     = false
}

# ============================================================
# RDS - Monitoring
# ============================================================

variable "rds_monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds. 0 disables Enhanced Monitoring."
  type        = number
  default     = 0

  validation {
    condition = contains(
      [
        0,
        1,
        5,
        10,
        15,
        30,
        60
      ],
      var.rds_monitoring_interval
    )

    error_message = "rds_monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "rds_monitoring_role_arn" {
  description = "Optional IAM role ARN used by RDS Enhanced Monitoring."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_performance_insights_enabled" {
  description = "Whether RDS Performance Insights is enabled."
  type        = bool
  default     = false
}

variable "rds_enabled_cloudwatch_logs_exports" {
  description = "RDS log types exported to CloudWatch Logs."
  type        = list(string)
  default     = []
}