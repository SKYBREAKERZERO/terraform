# ============================================================
# Lambda - General
# ============================================================

variable "lambda_enabled" {
  description = "Whether Lambda resources are created in this environment."
  type        = bool
  default     = true
}

variable "lambda_function_name" {
  description = "Optional Lambda function name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.lambda_function_name == null ||
      (
        length(trimspace(var.lambda_function_name)) > 0 &&
        length(var.lambda_function_name) <= 64 &&
        can(regex(
          "^[A-Za-z0-9_-]+$",
          var.lambda_function_name
        ))
      )
    )

    error_message = "lambda_function_name must be null or contain 1-64 characters using letters, numbers, hyphens, or underscores."
  }
}

variable "lambda_description" {
  description = "Description of the Lambda function."
  type        = string
  default     = "Managed by Terraform"

  validation {
    condition     = length(var.lambda_description) <= 256
    error_message = "lambda_description must not exceed 256 characters."
  }
}


# ============================================================
# Lambda - IAM
# ============================================================

variable "lambda_role_arn" {
  description = "IAM execution role ARN used by the Lambda function."
  type        = string

  validation {
    condition = (
      length(trimspace(var.lambda_role_arn)) > 0 &&
      can(regex(
        "^arn:[^:]+:iam::[0-9]{12}:role/.+$",
        var.lambda_role_arn
      ))
    )

    error_message = "lambda_role_arn must be a valid IAM role ARN."
  }
}


# ============================================================
# Lambda - Deployment Package
# ============================================================

variable "lambda_filename" {
  description = "Path to the Lambda ZIP deployment package."
  type        = string

  validation {
    condition = (
      length(trimspace(var.lambda_filename)) > 0 &&
      endswith(
        lower(var.lambda_filename),
        ".zip"
      )
    )

    error_message = "lambda_filename must reference a non-empty .zip deployment package."
  }
}


# ============================================================
# Lambda - Runtime
# ============================================================

variable "lambda_runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.13"

  validation {
    condition     = length(trimspace(var.lambda_runtime)) > 0
    error_message = "lambda_runtime must not be empty."
  }
}

variable "lambda_handler" {
  description = "Lambda function entry point."
  type        = string
  default     = "lambda_function.lambda_handler"

  validation {
    condition     = length(trimspace(var.lambda_handler)) > 0
    error_message = "lambda_handler must not be empty."
  }
}

variable "lambda_architectures" {
  description = "Instruction set architecture for the Lambda function."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition = (
      length(var.lambda_architectures) == 1 &&
      contains(
        [
          "x86_64",
          "arm64",
        ],
        var.lambda_architectures[0]
      )
    )

    error_message = "lambda_architectures must contain exactly one value: x86_64 or arm64."
  }
}


# ============================================================
# Lambda - Compute
# ============================================================

variable "lambda_memory_size" {
  description = "Amount of memory in MB available to the Lambda function."
  type        = number
  default     = 128

  validation {
    condition = (
      var.lambda_memory_size >= 128 &&
      var.lambda_memory_size <= 10240
    )

    error_message = "lambda_memory_size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Maximum Lambda execution time in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.lambda_timeout >= 1 &&
      var.lambda_timeout <= 900
    )

    error_message = "lambda_timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_ephemeral_storage_size" {
  description = "Lambda /tmp ephemeral storage size in MB."
  type        = number
  default     = 512

  validation {
    condition = (
      var.lambda_ephemeral_storage_size >= 512 &&
      var.lambda_ephemeral_storage_size <= 10240
    )

    error_message = "lambda_ephemeral_storage_size must be between 512 and 10240 MB."
  }
}


# ============================================================
# Lambda - Environment Variables
# ============================================================

variable "lambda_environment_variables" {
  description = "Environment variables configured for the Lambda function."
  type        = map(string)

  default = {
    ENVIRONMENT = "localstack"
    LOG_LEVEL   = "INFO"
  }
}


# ============================================================
# Lambda - Encryption
# ============================================================

variable "lambda_kms_key_arn" {
  description = "Optional KMS key ARN used to encrypt Lambda environment variables."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.lambda_kms_key_arn == null ||
      (
        length(trimspace(var.lambda_kms_key_arn)) > 0 &&
        can(regex(
          "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$",
          var.lambda_kms_key_arn
        ))
      )
    )

    error_message = "lambda_kms_key_arn must be null or a valid KMS key ARN."
  }
}


# ============================================================
# Lambda - X-Ray
# ============================================================

variable "lambda_tracing_mode" {
  description = "AWS X-Ray tracing mode."
  type        = string
  default     = "PassThrough"

  validation {
    condition = contains(
      [
        "PassThrough",
        "Active",
      ],
      var.lambda_tracing_mode
    )

    error_message = "lambda_tracing_mode must be PassThrough or Active."
  }
}


# ============================================================
# Lambda - Concurrency
# ============================================================

variable "lambda_reserved_concurrent_executions" {
  description = "Reserved concurrent executions. -1 means unreserved."
  type        = number
  default     = -1

  validation {
    condition = (
      var.lambda_reserved_concurrent_executions == -1 ||
      (
        var.lambda_reserved_concurrent_executions >= 0 &&
        floor(
          var.lambda_reserved_concurrent_executions
        ) == var.lambda_reserved_concurrent_executions
      )
    )

    error_message = "lambda_reserved_concurrent_executions must be -1 or a non-negative integer."
  }
}


# ============================================================
# Lambda - Versioning
# ============================================================

variable "lambda_publish" {
  description = "Whether to publish a new Lambda version."
  type        = bool
  default     = false
}


# ============================================================
# Lambda - Layers
# ============================================================

variable "lambda_layers" {
  description = "Optional list of Lambda Layer ARNs."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for layer in var.lambda_layers :
      length(trimspace(layer)) > 0
    ])

    error_message = "lambda_layers must contain only non-empty values."
  }
}