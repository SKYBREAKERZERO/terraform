# ============================================================
# Lambda - General
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

variable "function_name" {
  description = "Optional Lambda function name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.function_name == null ||
      (
        length(trimspace(var.function_name)) >= 1 &&
        length(trimspace(var.function_name)) <= 64 &&
        can(
          regex(
            "^[A-Za-z0-9_-]+$",
            var.function_name
          )
        )
      )
    )

    error_message = "function_name must be null or 1-64 characters using letters, numbers, hyphens, or underscores."
  }
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = "Managed by Terraform"

  validation {
    condition = (
      length(var.description) <= 256
    )

    error_message = "description must not exceed 256 characters."
  }
}


# ============================================================
# Lambda - IAM
# ============================================================

variable "role_arn" {
  description = "IAM execution role ARN used by the Lambda function."
  type        = string

  validation {
    condition = can(
      regex(
        "^arn:[^:]+:iam::[0-9]{12}:role/.+$",
        var.role_arn
      )
    )

    error_message = "role_arn must be a valid IAM role ARN."
  }
}


# ============================================================
# Lambda - Deployment Package
# ============================================================

variable "filename" {
  description = "Path to the Lambda deployment ZIP archive."
  type        = string

  validation {
    condition = (
      length(trimspace(var.filename)) > 0 &&
      endswith(
        lower(var.filename),
        ".zip"
      )
    )

    error_message = "filename must reference a non-empty .zip file path."
  }
}


# ============================================================
# Lambda - Runtime
# ============================================================

variable "runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.13"

  validation {
    condition = (
      length(trimspace(var.runtime)) > 0
    )

    error_message = "runtime must not be empty."
  }
}

variable "handler" {
  description = "Lambda function handler."
  type        = string
  default     = "lambda_function.lambda_handler"

  validation {
    condition = (
      length(trimspace(var.handler)) > 0
    )

    error_message = "handler must not be empty."
  }
}

variable "architectures" {
  description = "Lambda instruction set architecture."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition = (
      length(var.architectures) == 1 &&
      alltrue([
        for architecture in var.architectures :
        contains(
          [
            "x86_64",
            "arm64",
          ],
          architecture
        )
      ])
    )

    error_message = "architectures must contain exactly one value: x86_64 or arm64."
  }
}


# ============================================================
# Lambda - Compute
# ============================================================

variable "memory_size" {
  description = "Lambda memory allocation in MB."
  type        = number
  default     = 128

  validation {
    condition = (
      var.memory_size >= 128 &&
      var.memory_size <= 10240 &&
      floor(var.memory_size) == var.memory_size
    )

    error_message = "memory_size must be an integer between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Lambda execution timeout in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.timeout >= 1 &&
      var.timeout <= 900 &&
      floor(var.timeout) == var.timeout
    )

    error_message = "timeout must be an integer between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_size" {
  description = "Lambda ephemeral storage size in MB."
  type        = number
  default     = 512

  validation {
    condition = (
      var.ephemeral_storage_size >= 512 &&
      var.ephemeral_storage_size <= 10240 &&
      floor(var.ephemeral_storage_size)
      == var.ephemeral_storage_size
    )

    error_message = "ephemeral_storage_size must be an integer between 512 and 10240 MB."
  }
}


# ============================================================
# Lambda - Environment Variables
# ============================================================

variable "environment_variables" {
  description = "Environment variables passed to the Lambda function."
  type        = map(string)

  default = {
    ENVIRONMENT = "localstack"
    LOG_LEVEL   = "INFO"
  }
}


# ============================================================
# Lambda - Encryption
# ============================================================

variable "kms_key_arn" {
  description = "Optional KMS key ARN used to encrypt Lambda environment variables."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.kms_key_arn == null ||
      can(
        regex(
          "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$",
          var.kms_key_arn
        )
      )
    )

    error_message = "kms_key_arn must be null or a valid KMS key ARN."
  }
}


# ============================================================
# Lambda - Tracing
# ============================================================

variable "tracing_mode" {
  description = "AWS X-Ray tracing mode."
  type        = string
  default     = "PassThrough"

  validation {
    condition = contains(
      [
        "PassThrough",
        "Active",
      ],
      var.tracing_mode
    )

    error_message = "tracing_mode must be PassThrough or Active."
  }
}


# ============================================================
# Lambda - Concurrency
# ============================================================

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions. Use -1 for unreserved concurrency."
  type        = number
  default     = -1

  validation {
    condition = (
      var.reserved_concurrent_executions == -1 ||
      (
        var.reserved_concurrent_executions >= 0 &&
        floor(var.reserved_concurrent_executions)
        == var.reserved_concurrent_executions
      )
    )

    error_message = "reserved_concurrent_executions must be -1 or a non-negative integer."
  }
}


# ============================================================
# Lambda - Versioning
# ============================================================

variable "publish" {
  description = "Whether to publish a new Lambda version when code or configuration changes."
  type        = bool
  default     = false
}


# ============================================================
# Lambda - Layers
# ============================================================

variable "layers" {
  description = "Lambda layer version ARNs."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for layer in var.layers :
      can(
        regex(
          "^arn:[^:]+:lambda:[^:]+:[0-9]{12}:layer:[A-Za-z0-9-_]+:[0-9]+$",
          layer
        )
      )
    ])

    error_message = "layers must contain only valid Lambda layer version ARNs."
  }
}


# ============================================================
# Lambda - VPC
# ============================================================

variable "vpc_subnet_ids" {
  description = "Subnet IDs used by the Lambda VPC configuration."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for subnet_id in var.vpc_subnet_ids :
      (
        length(trimspace(subnet_id)) > 0 &&
        can(
          regex(
            "^subnet-[A-Za-z0-9]+$",
            subnet_id
          )
        )
      )
    ])

    error_message = "vpc_subnet_ids must contain only valid subnet IDs."
  }
}

variable "vpc_security_group_ids" {
  description = "Security group IDs used by the Lambda VPC configuration."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for security_group_id in var.vpc_security_group_ids :
      (
        length(trimspace(security_group_id)) > 0 &&
        can(
          regex(
            "^sg-[A-Za-z0-9]+$",
            security_group_id
          )
        )
      )
    ])

    error_message = "vpc_security_group_ids must contain only valid security group IDs."
  }
}


# ============================================================
# Lambda - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to Lambda resources."
  type        = map(string)
  default     = {}
}