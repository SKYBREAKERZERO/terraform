# ============================================================
# EventBridge
# ============================================================

module "eventbridge" {
  count = var.eventbridge_enabled ? 1 : 0

  source = "../../modules/eventbridge"

  project_name = var.project_name
  environment  = var.environment


  # ==========================================================
  # Event Bus
  # ==========================================================

  create_custom_event_bus = (
    var.eventbridge_create_custom_event_bus
  )

  event_bus_name = (
    var.eventbridge_event_bus_name
  )


  # ==========================================================
  # Rules
  # ==========================================================

  rules = (
    var.eventbridge_rules
  )


  # ==========================================================
  # Targets
  # ==========================================================

  targets = (
    var.eventbridge_targets
  )


  # ==========================================================
  # Validation
  # ==========================================================

  validate_target_input_exclusivity = (
    var.eventbridge_validate_target_input_exclusivity
  )


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = local.common_tags
}