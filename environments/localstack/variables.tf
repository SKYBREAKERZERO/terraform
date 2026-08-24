# ============================================================
# General
# ============================================================

variable "project_name" {
  description = "Project name used for resource naming"
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
# AWS / LocalStack
# ============================================================

variable "aws_region" {
  description = "AWS region used by the LocalStack environment"
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition = contains(
      [
        "ap-northeast-1",
        "ap-northeast-3",
        "ap-southeast-1",
        "us-east-1",
        "us-west-2"
      ],
      var.aws_region
    )

    error_message = "aws_region is not an approved region."
  }
}

variable "aws_access_key" {
  description = "Mock AWS access key for LocalStack"
  type        = string
  sensitive   = true
  default     = "test"
}

variable "aws_secret_key" {
  description = "Mock AWS secret key for LocalStack"
  type        = string
  sensitive   = true
  default     = "test"
}

variable "localstack_endpoint" {
  description = "LocalStack gateway endpoint"
  type        = string
  default     = "http://localhost:4566"

  validation {
    condition     = can(regex("^https?://", var.localstack_endpoint))
    error_message = "localstack_endpoint must start with http:// or https://."
  }
}


# ============================================================
# Network - VPC
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "create_internet_gateway" {
  description = "Whether to create an Internet Gateway"
  type        = bool
  default     = true
}

variable "nat_gateway_mode" {
  description = "NAT Gateway deployment mode"
  type        = string
  default     = "one-per-az"

  validation {
    condition = contains(
      [
        "none",
        "single",
        "one-per-az"
      ],
      var.nat_gateway_mode
    )

    error_message = "nat_gateway_mode must be one of: none, single, one-per-az."
  }
}

variable "prevent_destroy" {
  description = "Whether critical network resources should be protected from accidental destruction"
  type        = bool
  default     = false
}


# ============================================================
# Network - Public Subnets
# ============================================================

variable "public_subnets" {
  description = "Public subnet configuration"

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "At least two public subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      can(cidrnetmask(subnet.cidr_block))
    ])

    error_message = "All public subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }
}


# ============================================================
# Network - Private Application Subnets
# ============================================================

variable "private_app_subnets" {
  description = "Private application subnet configuration"

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_app_subnets) >= 2
    error_message = "At least two private application subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_app_subnets) :
      can(cidrnetmask(subnet.cidr_block))
    ])

    error_message = "All private application subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }
}


# ============================================================
# Network - Private Database Subnets
# ============================================================

variable "private_db_subnets" {
  description = "Private database subnet configuration"

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_db_subnets) >= 2
    error_message = "At least two private database subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_db_subnets) :
      can(cidrnetmask(subnet.cidr_block))
    ])

    error_message = "All private database subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }
}


# ============================================================
# EC2
# ============================================================

variable "ec2_ami_id" {
  description = "AMI ID used by application EC2 instances"
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9A-Za-z]+$", var.ec2_ami_id))
    error_message = "ec2_ami_id must be a valid AMI identifier."
  }
}

variable "ec2_instance_type" {
  description = "EC2 instance type used by application instances"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.ec2_instance_type)) > 0
    error_message = "ec2_instance_type cannot be empty."
  }
}

variable "ec2_enable_detailed_monitoring" {
  description = "Whether EC2 detailed monitoring is enabled"
  type        = bool
  default     = false
}

variable "ec2_ebs_optimized" {
  description = "Whether EBS optimization is enabled"
  type        = bool
  default     = false
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20

  validation {
    condition = (
      var.ec2_root_volume_size >= 8 &&
      var.ec2_root_volume_size <= 1024
    )

    error_message = "ec2_root_volume_size must be between 8 and 1024 GiB."
  }
}

variable "ec2_root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"

  validation {
    condition = contains(
      [
        "gp2",
        "gp3"
      ],
      var.ec2_root_volume_type
    )

    error_message = "ec2_root_volume_type must be gp2 or gp3."
  }
}

variable "ec2_kms_key_id" {
  description = "Optional KMS key ARN or ID used for root EBS encryption"
  type        = string
  default     = null
  nullable    = true
}

variable "ec2_delete_on_termination" {
  description = "Whether the root EBS volume is deleted when the EC2 instance is terminated"
  type        = bool
  default     = true
}

variable "ec2_metadata_hop_limit" {
  description = "IMDS response hop limit"
  type        = number
  default     = 1

  validation {
    condition = (
      var.ec2_metadata_hop_limit >= 1 &&
      var.ec2_metadata_hop_limit <= 64
    )

    error_message = "ec2_metadata_hop_limit must be between 1 and 64."
  }
}

variable "ec2_user_data" {
  description = "Optional user data passed to application EC2 instances"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Security
# ============================================================

variable "localstack_use_default_security_group" {
  description = "Whether LocalStack EC2 instances use the VPC default security group for emulator compatibility"
  type        = bool
  default     = true
}


# ============================================================
# IAM
# ============================================================

variable "iam_enable_ssm" {
  description = "Whether SSM permissions are enabled for application EC2 instances"
  type        = bool
  default     = true
}

variable "iam_enable_cloudwatch_agent" {
  description = "Whether CloudWatch Agent permissions are enabled for application EC2 instances"
  type        = bool
  default     = true
}


# ============================================================
# S3
# ============================================================

variable "s3_bucket_name" {
  description = "Name of the S3 bucket used by the LocalStack environment"
  type        = string

  validation {
    condition = (
      length(var.s3_bucket_name) >= 3 &&
      length(var.s3_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.s3_bucket_name))
    )

    error_message = "s3_bucket_name must be 3-63 characters and use valid lowercase S3 bucket naming characters."
  }
}

variable "s3_force_destroy" {
  description = "Whether Terraform may delete a non-empty S3 bucket"
  type        = bool
  default     = true
}


# ============================================================
# S3 - Versioning
# ============================================================

variable "s3_versioning_enabled" {
  description = "Whether S3 bucket versioning is enabled"
  type        = bool
  default     = true
}


# ============================================================
# S3 - Encryption
# ============================================================

variable "s3_encryption_algorithm" {
  description = "Server-side encryption algorithm used by the S3 bucket"
  type        = string
  default     = "AES256"

  validation {
    condition = contains(
      [
        "AES256",
        "aws:kms"
      ],
      var.s3_encryption_algorithm
    )

    error_message = "s3_encryption_algorithm must be AES256 or aws:kms."
  }
}

variable "s3_kms_key_arn" {
  description = "Optional KMS key ARN used when SSE-KMS encryption is enabled"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.s3_kms_key_arn == null ||
      can(regex("^arn:aws:kms:", var.s3_kms_key_arn))
    )

    error_message = "s3_kms_key_arn must be null or a valid KMS key ARN."
  }
}

variable "s3_bucket_key_enabled" {
  description = "Whether S3 Bucket Key is enabled when SSE-KMS is used"
  type        = bool
  default     = false
}


# ============================================================
# S3 - Public Access Block
# ============================================================

variable "s3_block_public_acls" {
  description = "Whether S3 public ACLs are blocked"
  type        = bool
  default     = true
}

variable "s3_ignore_public_acls" {
  description = "Whether S3 public ACLs are ignored"
  type        = bool
  default     = true
}

variable "s3_block_public_policy" {
  description = "Whether S3 public bucket policies are blocked"
  type        = bool
  default     = true
}

variable "s3_restrict_public_buckets" {
  description = "Whether public S3 buckets are restricted"
  type        = bool
  default     = true
}


# ============================================================
# S3 - Lifecycle
# ============================================================

variable "s3_lifecycle_enabled" {
  description = "Whether S3 lifecycle management is enabled"
  type        = bool
  default     = false
}

variable "s3_transition_days" {
  description = "Number of days before S3 objects transition to STANDARD_IA"
  type        = number
  default     = 30

  validation {
    condition     = var.s3_transition_days >= 1
    error_message = "s3_transition_days must be at least 1."
  }
}

variable "s3_expiration_days" {
  description = "Number of days before S3 objects expire"
  type        = number
  default     = 365

  validation {
    condition     = var.s3_expiration_days >= 1
    error_message = "s3_expiration_days must be at least 1."
  }

  validation {
    condition     = var.s3_expiration_days > var.s3_transition_days
    error_message = "s3_expiration_days must be greater than s3_transition_days."
  }
}

variable "s3_noncurrent_version_expiration_days" {
  description = "Number of days before noncurrent S3 object versions expire"
  type        = number
  default     = 90

  validation {
    condition     = var.s3_noncurrent_version_expiration_days >= 1
    error_message = "s3_noncurrent_version_expiration_days must be at least 1."
  }
}