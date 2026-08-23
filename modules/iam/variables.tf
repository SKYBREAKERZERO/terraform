variable "project_name" {
  description = "Project name used for IAM resource naming"
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
    type = string

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
        error_message = "environment must be one of:localstack,dev,stg,prod."
    }
}

variable "enable_ssm" {
    description = "Whether SSM permissions are attached to the EC2 role"
    type = bool
    default = true
}

variable "enable_cloudwatch_agent" {
  description = "Whether CloudWatch Agent permissions are attached to the EC2 role"
  type = bool
  default = true
}

variable "common_tags" {
  description = "Common tags applied to IAM resources"
  type = map(string)
  default = {}
}