# ============================================================
# API Gateway - General
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

variable "api_name" {
  description = "Optional API Gateway HTTP API name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.api_name == null ||
      length(trimspace(var.api_name)) > 0
    )

    error_message = "api_name must be null or a non-empty string."
  }
}

variable "description" {
  description = "Description of the API Gateway HTTP API."
  type        = string
  default     = "Managed by Terraform"
}


# ============================================================
# API Gateway - Protocol
# ============================================================

variable "protocol_type" {
  description = "API Gateway protocol type."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
      ],
      var.protocol_type
    )

    error_message = "protocol_type must be HTTP."
  }
}


# ============================================================
# API Gateway - Integration
# ============================================================

variable "integration_type" {
  description = "API Gateway integration type."
  type        = string
  default     = "AWS_PROXY"

  validation {
    condition = contains(
      [
        "AWS_PROXY",
        "HTTP_PROXY",
        "HTTP",
      ],
      var.integration_type
    )

    error_message = "integration_type must be AWS_PROXY, HTTP_PROXY, or HTTP."
  }
}

variable "integration_uri" {
  description = "Integration URI, such as a Lambda function ARN."
  type        = string

  validation {
    condition = (
      length(trimspace(var.integration_uri)) > 0
    )

    error_message = "integration_uri must not be empty."
  }
}

variable "integration_method" {
  description = "HTTP method used by the integration."
  type        = string
  default     = "POST"

  validation {
    condition = contains(
      [
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
        "HEAD",
        "OPTIONS",
        "ANY",
      ],
      upper(var.integration_method)
    )

    error_message = "integration_method must be a valid HTTP method."
  }
}

variable "payload_format_version" {
  description = "Payload format version used by Lambda proxy integration."
  type        = string
  default     = "2.0"

  validation {
    condition = contains(
      [
        "1.0",
        "2.0",
      ],
      var.payload_format_version
    )

    error_message = "payload_format_version must be 1.0 or 2.0."
  }
}

variable "integration_timeout_milliseconds" {
  description = "Integration timeout in milliseconds."
  type        = number
  default     = 30000

  validation {
    condition = (
      var.integration_timeout_milliseconds >= 50 &&
      var.integration_timeout_milliseconds <= 30000 &&
      floor(var.integration_timeout_milliseconds)
      == var.integration_timeout_milliseconds
    )

    error_message = "integration_timeout_milliseconds must be an integer between 50 and 30000."
  }
}


# ============================================================
# API Gateway - Route
# ============================================================

variable "route_key" {
  description = "Route key, for example POST /orders or $default."
  type        = string
  default     = "POST /"

  validation {
    condition = (
      length(trimspace(var.route_key)) > 0
    )

    error_message = "route_key must not be empty."
  }
}

variable "route_authorization_type" {
  description = "Authorization type used by the route."
  type        = string
  default     = "NONE"

  validation {
    condition = contains(
      [
        "NONE",
        "JWT",
        "AWS_IAM",
      ],
      var.route_authorization_type
    )

    error_message = "route_authorization_type must be NONE, JWT, or AWS_IAM."
  }
}

variable "authorizer_id" {
  description = "Optional API Gateway authorizer ID."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.authorizer_id == null ||
      length(trimspace(var.authorizer_id)) > 0
    )

    error_message = "authorizer_id must be null or a non-empty string."
  }
}


# ============================================================
# API Gateway - Stage
# ============================================================

variable "stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "$default"

  validation {
    condition = (
      length(trimspace(var.stage_name)) > 0
    )

    error_message = "stage_name must not be empty."
  }
}

variable "auto_deploy" {
  description = "Whether API changes are automatically deployed."
  type        = bool
  default     = true
}


# ============================================================
# API Gateway - CORS
# ============================================================

variable "cors_enabled" {
  description = "Whether CORS configuration is enabled."
  type        = bool
  default     = false
}

variable "cors_allow_origins" {
  description = "Allowed origins for CORS."
  type        = list(string)
  default     = ["*"]

  validation {
    condition = alltrue([
      for origin in var.cors_allow_origins :
      length(trimspace(origin)) > 0
    ])

    error_message = "cors_allow_origins must contain only non-empty values."
  }
}

variable "cors_allow_methods" {
  description = "Allowed HTTP methods for CORS."
  type        = list(string)
  default = [
    "GET",
    "POST",
    "OPTIONS",
  ]

  validation {
    condition = alltrue([
      for method in var.cors_allow_methods :
      contains(
        [
          "GET",
          "POST",
          "PUT",
          "PATCH",
          "DELETE",
          "HEAD",
          "OPTIONS",
        ],
        upper(method)
      )
    ])

    error_message = "cors_allow_methods contains an invalid HTTP method."
  }
}

variable "cors_allow_headers" {
  description = "Allowed request headers for CORS."
  type        = list(string)
  default = [
    "content-type",
    "authorization",
  ]
}

variable "cors_expose_headers" {
  description = "Response headers exposed by CORS."
  type        = list(string)
  default     = []
}

variable "cors_allow_credentials" {
  description = "Whether CORS allows credentials."
  type        = bool
  default     = false
}

variable "cors_max_age" {
  description = "Maximum number of seconds browsers cache CORS preflight results."
  type        = number
  default     = 0

  validation {
    condition = (
      var.cors_max_age >= 0 &&
      floor(var.cors_max_age) == var.cors_max_age
    )

    error_message = "cors_max_age must be a non-negative integer."
  }
}


# ============================================================
# API Gateway - Access Logging
# ============================================================

variable "access_logging_enabled" {
  description = "Whether API Gateway access logging is enabled."
  type        = bool
  default     = false
}

variable "access_log_destination_arn" {
  description = "Optional CloudWatch Logs log group ARN."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.access_log_destination_arn == null ||
      (
        length(trimspace(var.access_log_destination_arn)) > 0 &&
        can(regex(
          "^arn:[^:]+:logs:[^:]+:[0-9]{12}:log-group:.+$",
          var.access_log_destination_arn
        ))
      )
    )

    error_message = "access_log_destination_arn must be null or a valid CloudWatch Logs log group ARN."
  }
}

variable "access_log_format" {
  description = "Access log JSON format."
  type        = string

  default = jsonencode({
    requestId      = "$context.requestId"
    requestTime    = "$context.requestTime"
    httpMethod     = "$context.httpMethod"
    routeKey       = "$context.routeKey"
    status         = "$context.status"
    responseLength = "$context.responseLength"
    integrationErr = "$context.integrationErrorMessage"
  })

  validation {
    condition = (
      length(trimspace(var.access_log_format)) > 0
    )

    error_message = "access_log_format must not be empty."
  }
}


# ============================================================
# API Gateway - Throttling
# ============================================================

variable "throttling_burst_limit" {
  description = "Maximum burst request rate."
  type        = number
  default     = 100

  validation {
    condition = (
      var.throttling_burst_limit >= 0 &&
      floor(var.throttling_burst_limit)
      == var.throttling_burst_limit
    )

    error_message = "throttling_burst_limit must be a non-negative integer."
  }
}

variable "throttling_rate_limit" {
  description = "Steady-state request rate limit."
  type        = number
  default     = 50

  validation {
    condition = (
      var.throttling_rate_limit >= 0
    )

    error_message = "throttling_rate_limit must be non-negative."
  }
}


# ============================================================
# API Gateway - Lambda Permission
# ============================================================

variable "create_lambda_permission" {
  description = "Whether to create permission allowing API Gateway to invoke Lambda."
  type        = bool
  default     = true
}

variable "lambda_function_name" {
  description = "Optional Lambda function name used for aws_lambda_permission."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.lambda_function_name == null ||
      length(trimspace(var.lambda_function_name)) > 0
    )

    error_message = "lambda_function_name must be null or a non-empty string."
  }
}


# ============================================================
# API Gateway - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to API Gateway resources."
  type        = map(string)
  default     = {}
}