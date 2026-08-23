# ============================================================
# General
# ============================================================

variable "project_name" {
  description = "Project name used for EC2 resource naming"
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
      ["localstack", "dev", "stg", "prod"],
      var.environment
    )

    error_message = "environment must be one of: localstack, dev, stg, prod."
  }
}


# ============================================================
# EC2
# ============================================================

variable "ami_id" {
  description = "AMI ID used to launch EC2 instances"
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9A-Za-z]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI identifier."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type cannot be empty."
  }
}


# ============================================================
# Network
# ============================================================

variable "subnet_ids" {
  description = "Map of application subnet names to subnet IDs"
  type        = map(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet must be provided."
  }

  validation {
    condition = alltrue([
      for subnet_id in values(var.subnet_ids) :
      can(regex("^subnet-[0-9A-Za-z]+$", subnet_id))
    ])

    error_message = "All subnet_ids values must be valid subnet identifiers."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to EC2 instances"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for security_group_id in var.security_group_ids :
      can(regex("^sg-[0-9A-Za-z]+$", security_group_id))
    ])

    error_message = "All security_group_ids must be valid security group identifiers."
  }
}

variable "associate_public_ip_address" {
  description = "Whether EC2 instances receive public IP addresses"
  type        = bool
  default     = false
}


# ============================================================
# IAM
# ============================================================

variable "iam_instance_profile" {
  description = "IAM instance profile name attached to EC2 instances"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Monitoring / Performance
# ============================================================

variable "enable_detailed_monitoring" {
  description = "Whether EC2 detailed monitoring is enabled"
  type        = bool
  default     = false
}

variable "ebs_optimized" {
  description = "Whether EBS optimization is enabled"
  type        = bool
  default     = false
}


# ============================================================
# Root EBS Volume
# ============================================================

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20

  validation {
    condition = (
      var.root_volume_size >= 8 &&
      var.root_volume_size <= 1024
    )

    error_message = "root_volume_size must be between 8 and 1024 GiB."
  }
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"

  validation {
    condition = contains(
      ["gp2", "gp3"],
      var.root_volume_type
    )

    error_message = "root_volume_type must be gp2 or gp3."
  }
}

variable "root_volume_encrypted" {
  description = "Whether the root EBS volume is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN used for EBS encryption"
  type        = string
  default     = null
  nullable    = true
}

variable "delete_on_termination" {
  description = "Whether the root EBS volume is deleted when the instance terminates"
  type        = bool
  default     = true
}


# ============================================================
# Instance Metadata Service
# ============================================================

variable "metadata_http_tokens" {
  description = "IMDS token requirement"
  type        = string
  default     = "required"

  validation {
    condition = contains(
      ["required", "optional"],
      var.metadata_http_tokens
    )

    error_message = "metadata_http_tokens must be required or optional."
  }
}

variable "metadata_hop_limit" {
  description = "IMDS response hop limit"
  type        = number
  default     = 1

  validation {
    condition = (
      var.metadata_hop_limit >= 1 &&
      var.metadata_hop_limit <= 64
    )

    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}


# ============================================================
# Bootstrap
# ============================================================

variable "user_data" {
  description = "Optional user data passed to EC2 instances"
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to EC2 resources"
  type        = map(string)
  default     = {}
}


# ============================================================
# Lifecycle
# ============================================================

variable "prevent_destroy" {
  description = "Whether EC2 instances are protected from accidental Terraform destruction"
  type        = bool
  default     = false
}