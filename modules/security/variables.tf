# ============================================================
# General
# ============================================================

variable "project_name" {
  description = "Project name used for security resource naming"
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
# Network
# ============================================================

variable "vpc_id" {
  description = "VPC ID where security groups are created"
  type        = string

  validation {
    condition = can(
      regex(
        "^vpc-[0-9A-Za-z]+$",
        var.vpc_id
      )
    )

    error_message = "vpc_id must be a valid VPC identifier."
  }
}


# ============================================================
# Application Security Group
# ============================================================

variable "app_egress_cidr_ipv4" {
  description = "IPv4 CIDR allowed for application outbound traffic"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition = can(
      cidrhost(
        var.app_egress_cidr_ipv4,
        0
      )
    )

    error_message = "app_egress_cidr_ipv4 must be a valid IPv4 CIDR block."
  }
}


# ============================================================
# Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to security resources"
  type        = map(string)
  default     = {}
}