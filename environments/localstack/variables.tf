variable "project_name" {
  description = "Project name used for resource naming"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 30
    error_message = "project_name must be between 3 and 30 characters."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["localstack", "dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: localstack, dev, stg, prod."
  }
}

variable "aws_region" {
  description = "AWS region used by the LocalStack environment"
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition = contains([
      "ap-northeast-1",
      "ap-northeast-3",
      "ap-southeast-1",
      "us-east-1",
      "us-west-2"
    ], var.aws_region)
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
      can(cidrhost(subnet.cidr_block, 0))
    ])
    error_message = "All private database subnet CIDR blocks must be valid."
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
    condition     = contains(["none", "single", "one-per-az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: none, single, one-per-az."
  }
}

variable "prevent_destroy" {
  description = "Whether critical network resources should be protected from accidental destruction"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnets" {
  description = "Public subnet configuration"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "private_app_subnets" {
  description = "Private application subnet configuration"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}