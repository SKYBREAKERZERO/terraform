# ============================================================
# DynamoDB - General
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

variable "table_name" {
  description = "Optional DynamoDB table name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.table_name == null ||
      (
        length(trimspace(var.table_name)) >= 3 &&
        length(var.table_name) <= 255 &&
        can(regex(
          "^[A-Za-z0-9_.-]+$",
          var.table_name
        ))
      )
    )

    error_message = "table_name must be null or contain 3-255 characters using letters, numbers, '_', '-', or '.'."
  }
}


# ============================================================
# DynamoDB - Keys
# ============================================================

variable "hash_key" {
  description = "Partition key attribute name."
  type        = string

  validation {
    condition = (
      length(trimspace(var.hash_key)) > 0
    )

    error_message = "hash_key must not be empty."
  }
}

variable "hash_key_type" {
  description = "Partition key attribute type."
  type        = string
  default     = "S"

  validation {
    condition = contains(
      [
        "S",
        "N",
        "B",
      ],
      var.hash_key_type
    )

    error_message = "hash_key_type must be S, N, or B."
  }
}

variable "range_key" {
  description = "Optional sort key attribute name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.range_key == null ||
      length(trimspace(var.range_key)) > 0
    )

    error_message = "range_key must be null or a non-empty string."
  }
}

variable "range_key_type" {
  description = "Sort key attribute type."
  type        = string
  default     = "S"

  validation {
    condition = contains(
      [
        "S",
        "N",
        "B",
      ],
      var.range_key_type
    )

    error_message = "range_key_type must be S, N, or B."
  }
}


# ============================================================
# DynamoDB - Billing
# ============================================================

variable "billing_mode" {
  description = "DynamoDB billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition = contains(
      [
        "PAY_PER_REQUEST",
        "PROVISIONED",
      ],
      var.billing_mode
    )

    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Provisioned read capacity units."
  type        = number
  default     = 5

  validation {
    condition = (
      var.read_capacity >= 1 &&
      floor(var.read_capacity) == var.read_capacity
    )

    error_message = "read_capacity must be a positive integer."
  }
}

variable "write_capacity" {
  description = "Provisioned write capacity units."
  type        = number
  default     = 5

  validation {
    condition = (
      var.write_capacity >= 1 &&
      floor(var.write_capacity) == var.write_capacity
    )

    error_message = "write_capacity must be a positive integer."
  }
}


# ============================================================
# DynamoDB - TTL
# ============================================================

variable "ttl_enabled" {
  description = "Whether DynamoDB TTL is enabled."
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "TTL attribute name."
  type        = string
  default     = "expires_at"

  validation {
    condition = (
      length(trimspace(var.ttl_attribute_name)) > 0
    )

    error_message = "ttl_attribute_name must not be empty."
  }
}


# ============================================================
# DynamoDB - Point-in-Time Recovery
# ============================================================

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled."
  type        = bool
  default     = false
}


# ============================================================
# DynamoDB - Encryption
# ============================================================

variable "server_side_encryption_enabled" {
  description = "Whether DynamoDB server-side encryption is enabled."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kms_key_arn == null ||
      can(regex(
        "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$",
        var.kms_key_arn
      ))
    )

    error_message = "kms_key_arn must be null or a valid KMS key ARN."
  }
}


# ============================================================
# DynamoDB - Streams
# ============================================================

variable "stream_enabled" {
  description = "Whether DynamoDB Streams is enabled."
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "DynamoDB stream view type."
  type        = string
  default     = "NEW_AND_OLD_IMAGES"

  validation {
    condition = contains(
      [
        "KEYS_ONLY",
        "NEW_IMAGE",
        "OLD_IMAGE",
        "NEW_AND_OLD_IMAGES",
      ],
      var.stream_view_type
    )

    error_message = "stream_view_type must be KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, or NEW_AND_OLD_IMAGES."
  }
}


# ============================================================
# DynamoDB - Deletion Protection
# ============================================================

variable "deletion_protection_enabled" {
  description = "Whether DynamoDB table deletion protection is enabled."
  type        = bool
  default     = false
}


# ============================================================
# DynamoDB - Table Class
# ============================================================

variable "table_class" {
  description = "DynamoDB table class."
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      [
        "STANDARD",
        "STANDARD_INFREQUENT_ACCESS",
      ],
      var.table_class
    )

    error_message = "table_class must be STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}


# ============================================================
# DynamoDB - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to the DynamoDB table."
  type        = map(string)
  default     = {}
}