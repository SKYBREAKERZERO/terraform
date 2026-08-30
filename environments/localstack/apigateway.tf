# ============================================================
# API Gateway
# ============================================================

module "apigateway" {
  count = (
    var.apigateway_enabled
    ? 1
    : 0
  )

  source = "../../modules/apigateway"


  # ==========================================================
  # General
  # ==========================================================

  project_name = var.project_name
  environment  = var.environment

  api_name = (
    var.apigateway_api_name
  )

  description = (
    var.apigateway_description
  )


  # ==========================================================
  # Protocol
  # ==========================================================

  protocol_type = (
    var.apigateway_protocol_type
  )


  # ==========================================================
  # Integration
  # ==========================================================

  integration_type = (
    var.apigateway_integration_type
  )

  integration_uri = (
    module.lambda[0].function_arn
  )

  integration_method = (
    var.apigateway_integration_method
  )

  payload_format_version = (
    var.apigateway_payload_format_version
  )

  integration_timeout_milliseconds = (
    var.apigateway_integration_timeout_milliseconds
  )


  # ==========================================================
  # Route
  # ==========================================================

  route_key = (
    var.apigateway_route_key
  )

  route_authorization_type = (
    var.apigateway_route_authorization_type
  )

  authorizer_id = (
    var.apigateway_authorizer_id
  )


  # ==========================================================
  # Stage
  # ==========================================================

  stage_name = (
    var.apigateway_stage_name
  )

  auto_deploy = (
    var.apigateway_auto_deploy
  )


  # ==========================================================
  # CORS
  # ==========================================================

  cors_enabled = (
    var.apigateway_cors_enabled
  )

  cors_allow_origins = (
    var.apigateway_cors_allow_origins
  )

  cors_allow_methods = (
    var.apigateway_cors_allow_methods
  )

  cors_allow_headers = (
    var.apigateway_cors_allow_headers
  )

  cors_expose_headers = (
    var.apigateway_cors_expose_headers
  )

  cors_allow_credentials = (
    var.apigateway_cors_allow_credentials
  )

  cors_max_age = (
    var.apigateway_cors_max_age
  )


  # ==========================================================
  # Access Logging
  # ==========================================================

  access_logging_enabled = (
    var.apigateway_access_logging_enabled
  )

  access_log_destination_arn = (
    var.apigateway_access_log_destination_arn
  )

  access_log_format = (
    var.apigateway_access_log_format
  )


  # ==========================================================
  # Throttling
  # ==========================================================

  throttling_burst_limit = (
    var.apigateway_throttling_burst_limit
  )

  throttling_rate_limit = (
    var.apigateway_throttling_rate_limit
  )


  # ==========================================================
  # Lambda Permission
  # ==========================================================

  create_lambda_permission = (
    var.apigateway_create_lambda_permission
  )

  lambda_function_name = (
    module.lambda[0].function_name
  )


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = (
    var.common_tags
  )


  # ==========================================================
  # Dependency
  # ==========================================================

  depends_on = [
    module.lambda,
  ]
}