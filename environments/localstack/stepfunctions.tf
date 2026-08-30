# ============================================================
# Step Functions
# ============================================================

module "stepfunctions" {
  count = var.stepfunctions_enabled ? 1 : 0

  source = "../../modules/stepfunctions"

  project_name = var.project_name
  environment  = var.environment


  # ==========================================================
  # State Machine
  # ==========================================================

  state_machine_name = (
    var.stepfunctions_state_machine_name
  )

  state_machine_type = (
    var.stepfunctions_state_machine_type
  )


  # ==========================================================
  # IAM
  # ==========================================================

  role_arn = (
    var.stepfunctions_role_arn
  )


  # ==========================================================
  # Definition
  # ==========================================================

  definition = (
    var.stepfunctions_definition
  )


  # ==========================================================
  # Logging
  # ==========================================================

  logging_enabled = (
    var.stepfunctions_logging_enabled
  )

  log_destination = (
    var.stepfunctions_log_destination
  )

  log_level = (
    var.stepfunctions_log_level
  )

  include_execution_data = (
    var.stepfunctions_include_execution_data
  )


  # ==========================================================
  # X-Ray
  # ==========================================================

  tracing_enabled = (
    var.stepfunctions_tracing_enabled
  )


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = local.common_tags
}