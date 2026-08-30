# ============================================================
# Kinesis - General
# ============================================================

variable "project_name" {
  description = "Project name used for resource naming and tags."
  type        = string

  validation {
    condition = (
      length(trimspace(var.project_name)) > 0
    )

    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition = (
      length(trimspace(var.environment)) > 0
    )

    error_message = "environment must not be empty."
  }
}

variable "stream_name" {
  description = "Optional Kinesis Data Stream name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.stream_name == null ||
      (
        length(trimspace(var.stream_name)) >= 1 &&
        length(var.stream_name) <= 128 &&
        can(regex(
          "^[A-Za-z0-9_.-]+$",
          var.stream_name
        ))
      )
    )

    error_message = "stream_name must be null or contain 1-128 characters using letters, numbers, '_', '-', or '.'."
  }
}


# ============================================================
# Kinesis - Stream Mode
# ============================================================

variable "stream_mode" {
  description = "Kinesis stream capacity mode."
  type        = string
  default     = "PROVISIONED"

  validation {
    condition = contains(
      [
        "PROVISIONED",
        "ON_DEMAND",
      ],
      var.stream_mode
    )

    error_message = "stream_mode must be PROVISIONED or ON_DEMAND."
  }
}


# ============================================================
# Kinesis - Shards
# ============================================================

variable "shard_count" {
  description = "Number of shards when stream_mode is PROVISIONED."
  type        = number
  default     = 1

  validation {
    condition = (
      var.shard_count >= 1 &&
      floor(var.shard_count) == var.shard_count
    )

    error_message = "shard_count must be a positive integer."
  }
}


# ============================================================
# Kinesis - Retention
# ============================================================

variable "retention_period" {
  description = "Kinesis stream retention period in hours."
  type        = number
  default     = 24

  validation {
    condition = (
      var.retention_period >= 24 &&
      var.retention_period <= 8760 &&
      floor(var.retention_period) == var.retention_period
    )

    error_message = "retention_period must be an integer between 24 and 8760 hours."
  }
}


# ============================================================
# Kinesis - Encryption
# ============================================================

variable "encryption_type" {
  description = "Server-side encryption type for the Kinesis stream."
  type        = string
  default     = "NONE"

  validation {
    condition = contains(
      [
        "NONE",
        "KMS",
      ],
      var.encryption_type
    )

    error_message = "encryption_type must be NONE or KMS."
  }
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN used when encryption_type is KMS."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kms_key_id == null ||
      length(trimspace(var.kms_key_id)) > 0
    )

    error_message = "kms_key_id must be null or a non-empty string."
  }
}


# ============================================================
# Kinesis - Shard Level Metrics
# ============================================================

variable "shard_level_metrics" {
  description = "Shard-level CloudWatch metrics enabled for the stream."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for metric in var.shard_level_metrics :
      contains(
        [
          "IncomingBytes",
          "IncomingRecords",
          "OutgoingBytes",
          "OutgoingRecords",
          "WriteProvisionedThroughputExceeded",
          "ReadProvisionedThroughputExceeded",
          "IteratorAgeMilliseconds",
          "ALL",
        ],
        metric
      )
    ])

    error_message = "shard_level_metrics contains an unsupported Kinesis metric."
  }
}


# ============================================================
# Kinesis - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to the Kinesis stream."
  type        = map(string)
  default     = {}
}