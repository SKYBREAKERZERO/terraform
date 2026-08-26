# ============================================================
# General
# ============================================================

variable "project_name" {
  description = "Project name used for RDS resource naming"
  type        = string

  validation {
    condition = (
      length(var.project_name) >= 3 &&
      length(var.project_name) <= 30 &&
      can(regex("^[a-z0-9-]+$", var.project_name))
    )

    error_message = "project_name must be 3-30 characters and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition = contains(
      [
        "localstack",
        "dev",
        "stg",
        "prod"
      ],
      var.environment
    )

    error_message = "environment must be one of: localstack, dev, stg, prod."
  }
}


# ============================================================
# Database Engine
# ============================================================

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"

  validation {
    condition = contains(
      [
        "mysql",
        "postgres"
      ],
      var.engine
    )

    error_message = "engine must be mysql or postgres."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = null
  nullable    = true
}

variable "instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "instance_class must start with db."
  }
}


# ============================================================
# Database Identity
# ============================================================

variable "db_identifier" {
  description = "RDS DB instance identifier"
  type        = string

  validation {
    condition = (
      length(var.db_identifier) >= 1 &&
      length(var.db_identifier) <= 63 &&
      can(regex("^[a-z][a-z0-9-]*$", var.db_identifier))
    )

    error_message = "db_identifier must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"

  validation {
    condition = can(
      regex(
        "^[A-Za-z][A-Za-z0-9_]*$",
        var.database_name
      )
    )

    error_message = "database_name must start with a letter and contain only letters, numbers, and underscores."
  }
}


# ============================================================
# Credentials
# ============================================================

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"

  validation {
    condition = (
      length(var.master_username) >= 1 &&
      length(var.master_username) <= 16 &&
      can(
        regex(
          "^[A-Za-z][A-Za-z0-9_]*$",
          var.master_username
        )
      )
    )

    error_message = "master_username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "master_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "master_password must contain at least 8 characters."
  }
}


# ============================================================
# Network
# ============================================================

variable "subnet_ids" {
  description = "Private database subnet IDs used by the DB subnet group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two database subnet IDs must be provided."
  }

  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids :
      can(regex("^subnet-[0-9A-Za-z]+$", subnet_id))
    ])

    error_message = "All subnet_ids must be valid subnet identifiers."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to the RDS instance"
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group ID must be provided."
  }

  validation {
    condition = alltrue([
      for security_group_id in var.security_group_ids :
      can(regex("^sg-[0-9A-Za-z]+$", security_group_id))
    ])

    error_message = "All security_group_ids must be valid security group identifiers."
  }
}

variable "publicly_accessible" {
  description = "Whether the RDS instance is publicly accessible"
  type        = bool
  default     = false
}

variable "port" {
  description = "Database listener port"
  type        = number
  default     = null
  nullable    = true

  validation {
    condition = (
      var.port == null ||
      (
        var.port >= 1 &&
        var.port <= 65535
      )
    )

    error_message = "port must be between 1 and 65535."
  }
}


# ============================================================
# Availability
# ============================================================

variable "multi_az" {
  description = "Whether Multi-AZ deployment is enabled"
  type        = bool
  default     = false
}


# ============================================================
# Storage
# ============================================================

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling limit in GiB; 0 disables storage autoscaling"
  type        = number
  default     = 0

  validation {
    condition = (
      var.max_allocated_storage == 0 ||
      var.max_allocated_storage >= var.allocated_storage
    )

    error_message = "max_allocated_storage must be 0 or greater than or equal to allocated_storage."
  }
}

variable "storage_type" {
  description = "RDS storage type"
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
      var.storage_type
    )

    error_message = "storage_type must be gp2, gp3, io1, or io2."
  }
}

variable "storage_encrypted" {
  description = "Whether RDS storage encryption is enabled"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "Optional KMS key ARN or ID used for RDS storage encryption"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Backup
# ============================================================

variable "backup_retention_period" {
  description = "Number of days automated backups are retained"
  type        = number
  default     = 7

  validation {
    condition = (
      var.backup_retention_period >= 0 &&
      var.backup_retention_period <= 35
    )

    error_message = "backup_retention_period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred automated backup window"
  type        = string
  default     = null
  nullable    = true
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Deletion Protection
# ============================================================

variable "deletion_protection" {
  description = "Whether deletion protection is enabled"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether Terraform skips creation of a final snapshot when deleting the DB instance"
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier when skip_final_snapshot is false"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Maintenance / Upgrade
# ============================================================

variable "auto_minor_version_upgrade" {
  description = "Whether minor engine upgrades are automatically applied"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether database modifications are applied immediately"
  type        = bool
  default     = false
}


# ============================================================
# Monitoring
# ============================================================

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds; 0 disables Enhanced Monitoring"
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
      var.monitoring_interval
    )

    error_message = "monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "monitoring_role_arn" {
  description = "IAM role ARN used by RDS Enhanced Monitoring"
  type        = string
  default     = null
  nullable    = true
}

variable "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  type        = bool
  default     = false
}


# ============================================================
# Logs
# ============================================================

variable "enabled_cloudwatch_logs_exports" {
  description = "Database log types exported to CloudWatch Logs"
  type        = list(string)
  default     = []
}


# ============================================================
# Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to RDS resources"
  type        = map(string)
  default     = {}
}