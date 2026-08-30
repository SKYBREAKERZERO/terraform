# ============================================================
# Lambda - General
# ============================================================

variable "project_name" {
  description = "Project name used for Lambda resource naming."
  type        = string

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}

variable "function_name" {
  description = "Optional Lambda function name. If null, a name is generated from project_name and environment."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.function_name == null ||
      (
        length(trimspace(var.function_name)) > 0 &&
        length(var.function_name) <= 64 &&
        can(regex(
          "^[A-Za-z0-9_-]+$",
          var.function_name
        ))
      )
    )

    error_message = "function_name must be null or contain 1-64 characters using letters, numbers, hyphens, or underscores."
  }
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = "Managed by Terraform"

  validation {
    condition     = length(var.description) <= 256
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
    condition = (
      length(trimspace(var.role_arn)) > 0 &&
      can(regex(
        "^arn:[^:]+:iam::[0-9]{12}:role/.+$",
        var.role_arn
      ))
    )

    error_message = "role_arn must be a valid IAM role ARN."
  }
}


# ============================================================
# Lambda - Deployment Package
# ============================================================

variable "filename" {
  description = "Path to the Lambda ZIP deployment package."
  type        = string

  validation {
    condition     = length(trimspace(var.filename)) > 0
    error_message = "filename must not be empty."
  }
}

variable "source_code_hash" {
  description = "Optional base64-encoded SHA256 hash of the Lambda deployment package."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.source_code_hash == null ||
      length(trimspace(var.source_code_hash)) > 0
    )

    error_message = "source_code_hash must be null or a non-empty string."
  }
}


# ============================================================
# Lambda - Runtime
# ============================================================

variable "runtime" {
  description = "Lambda runtime, for example python3.13."
  type        = string
  default     = "python3.13"

  validation {
    condition     = length(trimspace(var.runtime)) > 0
    error_message = "runtime must not be empty."
  }
}

variable "handler" {
  description = "Lambda function entry point."
  type        = string
  default     = "lambda_function.lambda_handler"

  validation {
    condition     = length(trimspace(var.handler)) > 0
    error_message = "handler must not be empty."
  }
}

variable "architectures" {
  description = "Instruction set architecture for the Lambda function."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition = (
      length(var.architectures) == 1 &&
      contains(
        [
          "x86_64",
          "arm64",
        ],
        var.architectures[0]
      )
    )

    error_message = "architectures must contain exactly one value: x86_64 or arm64."
  }
}


# ============================================================
# Lambda - Compute
# ============================================================

variable "memory_size" {
  description = "Amount of memory in MB available to the Lambda function."
  type        = number
  default     = 128

  validation {
    condition = (
      var.memory_size >= 128 &&
      var.memory_size <= 10240
    )

    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Maximum Lambda execution time in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.timeout >= 1 &&
      var.timeout <= 900
    )

    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_size" {
  description = "Lambda /tmp ephemeral storage size in MB."
  type        = number
  default     = 512

  validation {
    condition = (
      var.ephemeral_storage_size >= 512 &&
      var.ephemeral_storage_size <= 10240
    )

    error_message = "ephemeral_storage_size must be between 512 and 10240 MB."
  }
}


# ============================================================
# Lambda - Environment Variables
# ============================================================

variable "environment_variables" {
  description = "Environment variables configured for the Lambda function."
  type        = map(string)
  default     = {}
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
      (
        length(trimspace(var.kms_key_arn)) > 0 &&
        can(regex(
          "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$",
          var.kms_key_arn
        ))
      )
    )

    error_message = "kms_key_arn must be null or a valid KMS key ARN."
  }
}


# ============================================================
# Lambda - Tracing
# ============================================================

variable "tracing_mode" {
  description = "AWS X-Ray tracing mode for the Lambda function."
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
  description = "Reserved concurrent executions. -1 means unreserved."
  type        = number
  default     = -1

  validation {
    condition = (
      var.reserved_concurrent_executions == -1 ||
      var.reserved_concurrent_executions >= 0
    )

    error_message = "reserved_concurrent_executions must be -1 or greater than or equal to 0."
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
  description = "Optional list of Lambda Layer ARNs."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for layer in var.layers :
      length(trimspace(layer)) > 0
    ])

    error_message = "layers must contain only non-empty ARNs."
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