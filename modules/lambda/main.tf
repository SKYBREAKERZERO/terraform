# ============================================================
# Lambda - Locals
# ============================================================

locals {
  function_name = (
    var.function_name != null
    ? var.function_name
    : "${var.project_name}-${var.environment}-function"
  )
}


# ============================================================
# Lambda Function
# ============================================================

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description

  package_type = "Zip"

  role = var.role_arn


  # ==========================================================
  # Deployment Package
  # ==========================================================

  filename = var.filename

  source_code_hash = (
    var.source_code_hash
  )


  # ==========================================================
  # Runtime
  # ==========================================================

  runtime = var.runtime
  handler = var.handler

  architectures = (
    var.architectures
  )


  # ==========================================================
  # Compute
  # ==========================================================

  memory_size = var.memory_size
  timeout     = var.timeout

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }


  # ==========================================================
  # Environment Variables
  # ==========================================================

  dynamic "environment" {
    for_each = (
      length(var.environment_variables) > 0
      ? [1]
      : []
    )

    content {
      variables = var.environment_variables
    }
  }


  # ==========================================================
  # Encryption
  # ==========================================================

  kms_key_arn = var.kms_key_arn


  # ==========================================================
  # X-Ray
  # ==========================================================

  tracing_config {
    mode = var.tracing_mode
  }


  # ==========================================================
  # Concurrency
  # ==========================================================

  reserved_concurrent_executions = (
    var.reserved_concurrent_executions
  )


  # ==========================================================
  # Versioning
  # ==========================================================

  publish = var.publish


  # ==========================================================
  # Lambda Layers
  # ==========================================================

  layers = var.layers


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = local.function_name
      Component = "compute"
      Service   = "lambda"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        endswith(
          lower(var.filename),
          ".zip"
        )
      )

      error_message = "filename must reference a .zip Lambda deployment package."
    }

    precondition {
      condition = (
        var.reserved_concurrent_executions == -1 ||
        (
          var.reserved_concurrent_executions >= 0 &&
          floor(var.reserved_concurrent_executions) == var.reserved_concurrent_executions
        )
      )

      error_message = "reserved_concurrent_executions must be -1 or a non-negative integer."
    }
  }
}