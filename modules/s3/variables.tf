variable "project_name" {
  description = "Project name used for s3 resource naming"
  type = string

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
  type = string

  validation {
    condition = contains(
      ["localstack", "dev", "stg", "prod"],
      var.environment
    )
    error_message = "environment must be one of: localstack, dev, stg, prod."
  }
}

variable "bucket_name" {
  description = "Name of the s3 bucket"
  type = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-63 characters and use valid lowercase S3 bucket naming characters."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete the bucket even when it contains objects"
  type = bool
  default = false
}

variable "versioning_enabled" {
  description = "Whether S3 bucket versioning is enabled"
  type = bool
  default = true
}

variable "encryption_algorithm" {
  description = "Server-side encryption algorithm for the S3 bucket"
  type        = string
  default     = "AES256"

  validation {
    condition = contains(
      ["AES256", "aws:kms"],
      var.encryption_algorithm
    )

    error_message = "encryption_algorithm must be AES256 or aws:kms."
  }
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN used when encryption_algorithm is aws:kms"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kms_key_arn == null ||
      can(regex("^arn:aws:kms:", var.kms_key_arn))
    )

    error_message = "kms_key_arn must be null or a valid AWS KMS key ARN."
  }
}

variable "block_public_acls" {
    description = "Whether to block public ACLs for the S3 bucket"
    type = bool
    default = true
}

variable "ignore_public_acls" {
    description = "Whether public ACLs are ignored"
    type = bool
    default = true
}

variable "block_public_policy" {
  description = "Whether public bucket policies are blocked"
  type = bool
  default = true
}

variable "restrict_public_buckets" {
  description = "Whether public bucket policies are restricted"
  type        = bool
  default     = true
}

variable "lifecycle_enabled" {
  description = "Whether the S3 lifecycle rule is enabled"
  type        = bool
  default     = false
}

variable "transition_days" {
  description = "Number of days before objects transition to STANDARD_IA"
  type        = number
  default     = 30

  validation {
    condition     = var.transition_days >= 1
    error_message = "transition_days must be at least 1."
  }
}

variable "expiration_days" {
  description = "Number of days before objects expire"
  type        = number
  default     = 365

  validation {
    condition     = var.expiration_days >= 1
    error_message = "expiration_days must be at least 1."
  }

  validation {
    condition     = var.expiration_days > var.transition_days
    error_message = "expiration_days must be greater than transition_days."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days before noncurrent object versions expire"
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "common_tags" {
  description = "Common tags applied to S3 resources"
  type        = map(string)
  default     = {}
}

variable "bucket_key_enabled" {
  description = "Whether S3 Bucket Key is enabled for SEE-KMS"
  type = bool
  default = true
}