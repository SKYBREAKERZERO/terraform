# ============================================================
# API Gateway - General
# ============================================================

variable "apigateway_enabled" {
  description = "Whether API Gateway resources are created in this environment."
  type        = bool
  default     = true
}

variable "apigateway_api_name" {
  description = "Optional API Gateway HTTP API name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.apigateway_api_name == null ||
      length(trimspace(var.apigateway_api_name)) > 0
    )

    error_message = "apigateway_api_name must be null or a non-empty string."
  }
}

variable "apigateway_description" {
  description = "Description of the API Gateway HTTP API."
  type        = string
  default     = "Managed by Terraform"

  validation {
    condition = (
      length(var.apigateway_description) <= 1024
    )

    error_message = "apigateway_description must not exceed 1024 characters."
  }
}


# ============================================================
# API Gateway - Protocol
# ============================================================

variable "apigateway_protocol_type" {
  description = "API Gateway protocol type."
  type        = string
  default     = "HTTP"

  validation {
    condition = (
      var.apigateway_protocol_type == "HTTP"
    )

    error_message = "apigateway_protocol_type must be HTTP."
  }
}


# ============================================================
# API Gateway - Integration
# ============================================================

variable "apigateway_integration_type" {
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
      var.apigateway_integration_type
    )

    error_message = "apigateway_integration_type must be AWS_PROXY, HTTP_PROXY, or HTTP."
  }
}

variable "apigateway_integration_method" {
  description = "HTTP method used by the API Gateway integration."
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
      upper(var.apigateway_integration_method)
    )

    error_message = "apigateway_integration_method must be a valid HTTP method."
  }
}

variable "apigateway_payload_format_version" {
  description = "Payload format version for Lambda proxy integration."
  type        = string
  default     = "2.0"

  validation {
    condition = contains(
      [
        "1.0",
        "2.0",
      ],
      var.apigateway_payload_format_version
    )

    error_message = "apigateway_payload_format_version must be 1.0 or 2.0."
  }
}

variable "apigateway_integration_timeout_milliseconds" {
  description = "API Gateway integration timeout in milliseconds."
  type        = number
  default     = 30000

  validation {
    condition = (
      var.apigateway_integration_timeout_milliseconds >= 50 &&
      var.apigateway_integration_timeout_milliseconds <= 30000 &&
      floor(
        var.apigateway_integration_timeout_milliseconds
      ) == var.apigateway_integration_timeout_milliseconds
    )

    error_message = "apigateway_integration_timeout_milliseconds must be an integer between 50 and 30000."
  }
}


# ============================================================
# API Gateway - Route
# ============================================================

variable "apigateway_route_key" {
  description = "API Gateway route key, for example POST /orders or $default."
  type        = string
  default     = "POST /"

  validation {
    condition = (
      length(trimspace(var.apigateway_route_key)) > 0
    )

    error_message = "apigateway_route_key must not be empty."
  }
}

variable "apigateway_route_authorization_type" {
  description = "Authorization type used by the API Gateway route."
  type        = string
  default     = "NONE"

  validation {
    condition = contains(
      [
        "NONE",
        "JWT",
        "AWS_IAM",
      ],
      var.apigateway_route_authorization_type
    )

    error_message = "apigateway_route_authorization_type must be NONE, JWT, or AWS_IAM."
  }
}

variable "apigateway_authorizer_id" {
  description = "Optional API Gateway authorizer ID."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.apigateway_authorizer_id == null ||
      length(trimspace(var.apigateway_authorizer_id)) > 0
    )

    error_message = "apigateway_authorizer_id must be null or a non-empty string."
  }
}


# ============================================================
# API Gateway - Stage
# ============================================================

variable "apigateway_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "$default"

  validation {
    condition = (
      length(trimspace(var.apigateway_stage_name)) > 0
    )

    error_message = "apigateway_stage_name must not be empty."
  }
}

variable "apigateway_auto_deploy" {
  description = "Whether API Gateway stage changes are automatically deployed."
  type        = bool
  default     = true
}


# ============================================================
# API Gateway - CORS
# ============================================================

variable "apigateway_cors_enabled" {
  description = "Whether API Gateway CORS configuration is enabled."
  type        = bool
  default     = false
}

variable "apigateway_cors_allow_origins" {
  description = "Allowed origins for API Gateway CORS."
  type        = list(string)
  default     = ["*"]

  validation {
    condition = alltrue([
      for origin in var.apigateway_cors_allow_origins :
      length(trimspace(origin)) > 0
    ])

    error_message = "apigateway_cors_allow_origins must contain only non-empty values."
  }
}

variable "apigateway_cors_allow_methods" {
  description = "Allowed HTTP methods for API Gateway CORS."
  type        = list(string)

  default = [
    "GET",
    "POST",
    "OPTIONS",
  ]

  validation {
    condition = alltrue([
      for method in var.apigateway_cors_allow_methods :
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

    error_message = "apigateway_cors_allow_methods contains an invalid HTTP method."
  }
}

variable "apigateway_cors_allow_headers" {
  description = "Allowed request headers for API Gateway CORS."
  type        = list(string)

  default = [
    "content-type",
    "authorization",
  ]

  validation {
    condition = alltrue([
      for header in var.apigateway_cors_allow_headers :
      length(trimspace(header)) > 0
    ])

    error_message = "apigateway_cors_allow_headers must contain only non-empty values."
  }
}

variable "apigateway_cors_expose_headers" {
  description = "Response headers exposed by API Gateway CORS."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for header in var.apigateway_cors_expose_headers :
      length(trimspace(header)) > 0
    ])

    error_message = "apigateway_cors_expose_headers must contain only non-empty values."
  }
}

variable "apigateway_cors_allow_credentials" {
  description = "Whether API Gateway CORS allows credentials."
  type        = bool
  default     = false
}

variable "apigateway_cors_max_age" {
  description = "Maximum number of seconds browsers cache CORS preflight responses."
  type        = number
  default     = 0

  validation {
    condition = (
      var.apigateway_cors_max_age >= 0 &&
      floor(var.apigateway_cors_max_age)
      == var.apigateway_cors_max_age
    )

    error_message = "apigateway_cors_max_age must be a non-negative integer."
  }
}


# ============================================================
# API Gateway - Access Logging
# ============================================================

variable "apigateway_access_logging_enabled" {
  description = "Whether API Gateway access logging is enabled."
  type        = bool
  default     = false
}

variable "apigateway_access_log_destination_arn" {
  description = "Optional CloudWatch Logs log group ARN used for API Gateway access logs."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.apigateway_access_log_destination_arn == null ||
      (
        length(
          trimspace(
            var.apigateway_access_log_destination_arn
          )
        ) > 0 &&
        can(regex(
          "^arn:[^:]+:logs:[^:]+:[0-9]{12}:log-group:.+$",
          var.apigateway_access_log_destination_arn
        ))
      )
    )

    error_message = "apigateway_access_log_destination_arn must be null or a valid CloudWatch Logs log group ARN."
  }
}

variable "apigateway_access_log_format" {
  description = "API Gateway access log format."
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
      length(
        trimspace(
          var.apigateway_access_log_format
        )
      ) > 0
    )

    error_message = "apigateway_access_log_format must not be empty."
  }
}


# ============================================================
# API Gateway - Throttling
# ============================================================

variable "apigateway_throttling_burst_limit" {
  description = "API Gateway default route throttling burst limit."
  type        = number
  default     = 100

  validation {
    condition = (
      var.apigateway_throttling_burst_limit >= 0 &&
      floor(
        var.apigateway_throttling_burst_limit
      ) == var.apigateway_throttling_burst_limit
    )

    error_message = "apigateway_throttling_burst_limit must be a non-negative integer."
  }
}

variable "apigateway_throttling_rate_limit" {
  description = "API Gateway default route throttling rate limit."
  type        = number
  default     = 50

  validation {
    condition = (
      var.apigateway_throttling_rate_limit >= 0
    )

    error_message = "apigateway_throttling_rate_limit must be non-negative."
  }
}


# ============================================================
# API Gateway - Lambda Permission
# ============================================================

variable "apigateway_create_lambda_permission" {
  description = "Whether permission allowing API Gateway to invoke Lambda is created."
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags applied to resources."
  type        = map(string)
  default     = {}
}