# ============================================================
# API Gateway - Locals
# ============================================================

locals {
  api_name = (
    var.api_name != null
    ? var.api_name
    : "${var.project_name}-${var.environment}-api"
  )
}


# ============================================================
# API Gateway - HTTP API
# ============================================================

resource "aws_apigatewayv2_api" "this" {
  name          = local.api_name
  description   = var.description
  protocol_type = var.protocol_type


  # ==========================================================
  # CORS
  # ==========================================================

  dynamic "cors_configuration" {
    for_each = (
      var.cors_enabled
      ? [1]
      : []
    )

    content {
      allow_origins = var.cors_allow_origins
      allow_methods = var.cors_allow_methods
      allow_headers = var.cors_allow_headers

      expose_headers = var.cors_expose_headers

      allow_credentials = (
        var.cors_allow_credentials
      )

      max_age = var.cors_max_age
    }
  }


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = local.api_name
      Component = "api"
      Service   = "apigateway"
    }
  )
}


# ============================================================
# API Gateway - Integration
# ============================================================

resource "aws_apigatewayv2_integration" "this" {
  api_id = aws_apigatewayv2_api.this.id

  integration_type = (
    var.integration_type
  )

  integration_uri = (
    var.integration_uri
  )

  integration_method = (
    var.integration_method
  )

  payload_format_version = (
    var.payload_format_version
  )

  timeout_milliseconds = (
    var.integration_timeout_milliseconds
  )
}


# ============================================================
# API Gateway - Route
# ============================================================

resource "aws_apigatewayv2_route" "this" {
  api_id = aws_apigatewayv2_api.this.id

  route_key = var.route_key

  target = (
    "integrations/${aws_apigatewayv2_integration.this.id}"
  )

  authorization_type = (
    var.route_authorization_type
  )

  authorizer_id = (
    var.route_authorization_type == "JWT"
    ? var.authorizer_id
    : null
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        var.route_authorization_type != "JWT" ||
        var.authorizer_id != null
      )

      error_message = "authorizer_id must be provided when route_authorization_type is JWT."
    }
  }
}


# ============================================================
# API Gateway - Stage
# ============================================================

resource "aws_apigatewayv2_stage" "this" {
  api_id = aws_apigatewayv2_api.this.id

  name = var.stage_name

  auto_deploy = var.auto_deploy


  # ==========================================================
  # Access Logging
  # ==========================================================

  dynamic "access_log_settings" {
    for_each = (
      var.access_logging_enabled
      ? [1]
      : []
    )

    content {
      destination_arn = (
        var.access_log_destination_arn
      )

      format = (
        var.access_log_format
      )
    }
  }


  # ==========================================================
  # Default Route Settings
  # ==========================================================

  default_route_settings {
    throttling_burst_limit = (
      var.throttling_burst_limit
    )

    throttling_rate_limit = (
      var.throttling_rate_limit
    )
  }


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = "${local.api_name}-${var.stage_name}"
      Component = "api"
      Service   = "apigateway"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        !var.access_logging_enabled ||
        var.access_log_destination_arn != null
      )

      error_message = "access_log_destination_arn must be provided when access_logging_enabled is true."
    }
  }
}


# ============================================================
# Lambda Permission
# ============================================================

resource "aws_lambda_permission" "apigateway" {
  count = (
    var.create_lambda_permission
    ? 1
    : 0
  )

  statement_id = (
    "AllowExecutionFromAPIGateway"
  )

  action = (
    "lambda:InvokeFunction"
  )

  function_name = (
    var.lambda_function_name
  )

  principal = (
    "apigateway.amazonaws.com"
  )

  source_arn = (
    "${aws_apigatewayv2_api.this.execution_arn}/*/*"
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        var.lambda_function_name != null
      )

      error_message = "lambda_function_name must be provided when create_lambda_permission is true."
    }
  }
}