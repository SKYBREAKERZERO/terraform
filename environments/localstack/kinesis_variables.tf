# ============================================================
# Kinesis - General
# ============================================================

variable "kinesis_enabled" {
  description = "Whether Kinesis resources are created in this environment."
  type        = bool
  default     = true
}

variable "kinesis_stream_name" {
  description = "Optional Kinesis Data Stream name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kinesis_stream_name == null ||
      (
        length(trimspace(var.kinesis_stream_name)) >= 1 &&
        length(var.kinesis_stream_name) <= 128 &&
        can(regex(
          "^[A-Za-z0-9_.-]+$",
          var.kinesis_stream_name
        ))
      )
    )

    error_message = "kinesis_stream_name must be null or contain 1-128 characters using letters, numbers, '_', '-', or '.'."
  }
}


# ============================================================
# Kinesis - Stream Mode
# ============================================================

variable "kinesis_stream_mode" {
  description = "Kinesis stream capacity mode."
  type        = string
  default     = "PROVISIONED"

  validation {
    condition = contains(
      [
        "PROVISIONED",
        "ON_DEMAND",
      ],
      var.kinesis_stream_mode
    )

    error_message = "kinesis_stream_mode must be PROVISIONED or ON_DEMAND."
  }
}


# ============================================================
# Kinesis - Shards
# ============================================================

variable "kinesis_shard_count" {
  description = "Number of shards when using PROVISIONED mode."
  type        = number
  default     = 1

  validation {
    condition = (
      var.kinesis_shard_count >= 1 &&
      floor(var.kinesis_shard_count) == var.kinesis_shard_count
    )

    error_message = "kinesis_shard_count must be a positive integer."
  }
}


# ============================================================
# Kinesis - Retention
# ============================================================

variable "kinesis_retention_period" {
  description = "Kinesis stream retention period in hours."
  type        = number
  default     = 24

  validation {
    condition = (
      var.kinesis_retention_period >= 24 &&
      var.kinesis_retention_period <= 8760 &&
      floor(var.kinesis_retention_period) == var.kinesis_retention_period
    )

    error_message = "kinesis_retention_period must be an integer between 24 and 8760 hours."
  }
}


# ============================================================
# Kinesis - Encryption
# ============================================================

variable "kinesis_encryption_type" {
  description = "Server-side encryption type for the Kinesis stream."
  type        = string
  default     = "NONE"

  validation {
    condition = contains(
      [
        "NONE",
        "KMS",
      ],
      var.kinesis_encryption_type
    )

    error_message = "kinesis_encryption_type must be NONE or KMS."
  }
}

variable "kinesis_kms_key_id" {
  description = "Optional KMS key ID or ARN used when encryption type is KMS."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kinesis_kms_key_id == null ||
      length(trimspace(var.kinesis_kms_key_id)) > 0
    )

    error_message = "kinesis_kms_key_id must be null or a non-empty string."
  }
}


# ============================================================
# Kinesis - Shard Level Metrics
# ============================================================

variable "kinesis_shard_level_metrics" {
  description = "Shard-level CloudWatch metrics enabled for the stream."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for metric in var.kinesis_shard_level_metrics :
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

    error_message = "kinesis_shard_level_metrics contains an unsupported metric."
  }
}