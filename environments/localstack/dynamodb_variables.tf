# ============================================================
# DynamoDB - General
# ============================================================

variable "dynamodb_enabled" {
  description = "Whether DynamoDB resources are created in this environment."
  type        = bool
  default     = true
}

variable "dynamodb_table_name" {
  description = "Optional DynamoDB table name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.dynamodb_table_name == null ||
      (
        length(trimspace(var.dynamodb_table_name)) >= 3 &&
        length(var.dynamodb_table_name) <= 255 &&
        can(regex(
          "^[A-Za-z0-9_.-]+$",
          var.dynamodb_table_name
        ))
      )
    )

    error_message = "dynamodb_table_name must be null or contain 3-255 characters using letters, numbers, '_', '-', or '.'."
  }
}


# ============================================================
# DynamoDB - Keys
# ============================================================

variable "dynamodb_hash_key" {
  description = "DynamoDB partition key attribute name."
  type        = string
  default     = "id"

  validation {
    condition = (
      length(trimspace(var.dynamodb_hash_key)) > 0
    )

    error_message = "dynamodb_hash_key must not be empty."
  }
}

variable "dynamodb_hash_key_type" {
  description = "DynamoDB partition key attribute type."
  type        = string
  default     = "S"

  validation {
    condition = contains(
      [
        "S",
        "N",
        "B",
      ],
      var.dynamodb_hash_key_type
    )

    error_message = "dynamodb_hash_key_type must be S, N, or B."
  }
}

variable "dynamodb_range_key" {
  description = "Optional DynamoDB sort key attribute name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.dynamodb_range_key == null ||
      length(trimspace(var.dynamodb_range_key)) > 0
    )

    error_message = "dynamodb_range_key must be null or a non-empty string."
  }
}

variable "dynamodb_range_key_type" {
  description = "DynamoDB sort key attribute type."
  type        = string
  default     = "S"

  validation {
    condition = contains(
      [
        "S",
        "N",
        "B",
      ],
      var.dynamodb_range_key_type
    )

    error_message = "dynamodb_range_key_type must be S, N, or B."
  }
}


# ============================================================
# DynamoDB - Billing
# ============================================================

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition = contains(
      [
        "PAY_PER_REQUEST",
        "PROVISIONED",
      ],
      var.dynamodb_billing_mode
    )

    error_message = "dynamodb_billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_read_capacity" {
  description = "Provisioned read capacity units."
  type        = number
  default     = 5

  validation {
    condition = (
      var.dynamodb_read_capacity >= 1 &&
      floor(var.dynamodb_read_capacity)
      == var.dynamodb_read_capacity
    )

    error_message = "dynamodb_read_capacity must be a positive integer."
  }
}

variable "dynamodb_write_capacity" {
  description = "Provisioned write capacity units."
  type        = number
  default     = 5

  validation {
    condition = (
      var.dynamodb_write_capacity >= 1 &&
      floor(var.dynamodb_write_capacity)
      == var.dynamodb_write_capacity
    )

    error_message = "dynamodb_write_capacity must be a positive integer."
  }
}


# ============================================================
# DynamoDB - TTL
# ============================================================

variable "dynamodb_ttl_enabled" {
  description = "Whether DynamoDB TTL is enabled."
  type        = bool
  default     = false
}

variable "dynamodb_ttl_attribute_name" {
  description = "DynamoDB TTL attribute name."
  type        = string
  default     = "expires_at"

  validation {
    condition = (
      length(trimspace(var.dynamodb_ttl_attribute_name)) > 0
    )

    error_message = "dynamodb_ttl_attribute_name must not be empty."
  }
}


# ============================================================
# DynamoDB - Point-in-Time Recovery
# ============================================================

variable "dynamodb_point_in_time_recovery_enabled" {
  description = "Whether DynamoDB point-in-time recovery is enabled."
  type        = bool
  default     = false
}


# ============================================================
# DynamoDB - Encryption
# ============================================================

variable "dynamodb_server_side_encryption_enabled" {
  description = "Whether DynamoDB server-side encryption is enabled."
  type        = bool
  default     = true
}

variable "dynamodb_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.dynamodb_kms_key_arn == null ||
      can(regex(
        "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$",
        var.dynamodb_kms_key_arn
      ))
    )

    error_message = "dynamodb_kms_key_arn must be null or a valid KMS key ARN."
  }
}


# ============================================================
# DynamoDB - Streams
# ============================================================

variable "dynamodb_stream_enabled" {
  description = "Whether DynamoDB Streams is enabled."
  type        = bool
  default     = false
}

variable "dynamodb_stream_view_type" {
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
      var.dynamodb_stream_view_type
    )

    error_message = "dynamodb_stream_view_type must be KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, or NEW_AND_OLD_IMAGES."
  }
}


# ============================================================
# DynamoDB - Deletion Protection
# ============================================================

variable "dynamodb_deletion_protection_enabled" {
  description = "Whether DynamoDB deletion protection is enabled."
  type        = bool
  default     = false
}


# ============================================================
# DynamoDB - Table Class
# ============================================================

variable "dynamodb_table_class" {
  description = "DynamoDB table class."
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      [
        "STANDARD",
        "STANDARD_INFREQUENT_ACCESS",
      ],
      var.dynamodb_table_class
    )

    error_message = "dynamodb_table_class must be STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}