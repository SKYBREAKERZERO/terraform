# ============================================================
# API Gateway - API
# ============================================================

output "api_id" {
  description = "API Gateway HTTP API ID."
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "API Gateway HTTP API ARN."
  value       = aws_apigatewayv2_api.this.arn
}

output "api_execution_arn" {
  description = "API Gateway execution ARN."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "api_endpoint" {
  description = "Default API Gateway endpoint."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_name" {
  description = "API Gateway HTTP API name."
  value       = aws_apigatewayv2_api.this.name
}


# ============================================================
# API Gateway - Integration
# ============================================================

output "integration_id" {
  description = "API Gateway integration ID."
  value       = aws_apigatewayv2_integration.this.id
}


# ============================================================
# API Gateway - Route
# ============================================================

output "route_id" {
  description = "API Gateway route ID."
  value       = aws_apigatewayv2_route.this.id
}

output "route_key" {
  description = "API Gateway route key."
  value       = aws_apigatewayv2_route.this.route_key
}


# ============================================================
# API Gateway - Stage
# ============================================================

output "stage_id" {
  description = "API Gateway stage ID."
  value       = aws_apigatewayv2_stage.this.id
}

output "stage_name" {
  description = "API Gateway stage name."
  value       = aws_apigatewayv2_stage.this.name
}

output "stage_invoke_url" {
  description = "Invoke URL for the configured API Gateway stage."

  value = (
    var.stage_name == "$default"
    ? aws_apigatewayv2_api.this.api_endpoint
    : "${aws_apigatewayv2_api.this.api_endpoint}/${var.stage_name}"
  )
}


# ============================================================
# API Gateway - Lambda Permission
# ============================================================

output "lambda_permission_statement_id" {
  description = "Lambda permission statement ID created for API Gateway."

  value = (
    var.create_lambda_permission
    ? aws_lambda_permission.apigateway[0].statement_id
    : null
  )
}