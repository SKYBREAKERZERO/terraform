# ============================================================
# Step Functions - Locals
# ============================================================

locals {
  state_machine_name = (
    var.state_machine_name != null
    ? var.state_machine_name
    : "${var.project_name}-${var.environment}-workflow"
  )
}


# ============================================================
# Step Functions - State Machine
# ============================================================

resource "aws_sfn_state_machine" "this" {
  name = local.state_machine_name

  role_arn = var.role_arn

  type = var.state_machine_type

  definition = var.definition


  # ==========================================================
  # Logging
  # ==========================================================

  dynamic "logging_configuration" {
    for_each = (
      var.logging_enabled
      ? [1]
      : []
    )

    content {
      log_destination = var.log_destination

      include_execution_data = (
        var.include_execution_data
      )

      level = var.log_level
    }
  }


  # ==========================================================
  # X-Ray Tracing
  # ==========================================================

  tracing_configuration {
    enabled = var.tracing_enabled
  }


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = local.state_machine_name
      Component = "workflow"
      Service   = "stepfunctions"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        !var.logging_enabled ||
        (
          var.log_destination != null &&
          length(trimspace(var.log_destination)) > 0
        )
      )

      error_message = "log_destination must be configured when logging_enabled = true."
    }

    precondition {
      condition = (
        var.logging_enabled ||
        var.log_destination == null
      )

      error_message = "log_destination must be null when logging_enabled = false."
    }

    precondition {
      condition = can(
        jsondecode(
          var.definition
        )
      )

      error_message = "Step Functions definition must contain valid JSON."
    }
  }
}