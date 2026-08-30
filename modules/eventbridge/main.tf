# ============================================================
# EventBridge - Locals
# ============================================================

locals {
  custom_event_bus_name = (
    var.event_bus_name != null
    ? var.event_bus_name
    : "${var.project_name}-${var.environment}-events"
  )

  event_bus_name = (
    var.create_custom_event_bus
    ? aws_cloudwatch_event_bus.this[0].name
    : "default"
  )
}


# ============================================================
# EventBridge - Event Bus
# ============================================================

resource "aws_cloudwatch_event_bus" "this" {
  count = var.create_custom_event_bus ? 1 : 0

  name = local.custom_event_bus_name

  tags = merge(
    var.common_tags,
    {
      Name      = local.custom_event_bus_name
      Component = "messaging"
      Service   = "eventbridge"
    }
  )
}


# ============================================================
# EventBridge - Rules
# ============================================================

resource "aws_cloudwatch_event_rule" "this" {
  for_each = var.rules

  name = (
    each.value.name != null
    ? each.value.name
    : "${var.project_name}-${var.environment}-${each.key}"
  )

  description = each.value.description

  event_bus_name = local.event_bus_name

  event_pattern = each.value.event_pattern

  state = (
    each.value.enabled
    ? "ENABLED"
    : "DISABLED"
  )

  tags = merge(
    var.common_tags,
    each.value.tags,
    {
      Component = "messaging"
      Service   = "eventbridge"
      RuleKey   = each.key
    }
  )

  lifecycle {
    precondition {
      condition = can(
        jsondecode(
          each.value.event_pattern
        )
      )

      error_message = "EventBridge event_pattern must contain valid JSON."
    }
  }
}


# ============================================================
# EventBridge - Targets
# ============================================================

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.targets

  event_bus_name = local.event_bus_name

  rule = aws_cloudwatch_event_rule.this[
    each.value.rule_key
  ].name

  target_id = (
    each.value.target_id != null
    ? each.value.target_id
    : each.key
  )

  arn = each.value.arn

  role_arn = each.value.role_arn

  input = each.value.input

  input_path = each.value.input_path


  # ==========================================================
  # Input Transformer
  # ==========================================================

  dynamic "input_transformer" {
    for_each = (
      each.value.input_transformer != null
      ? [each.value.input_transformer]
      : []
    )

    content {
      input_paths = input_transformer.value.input_paths

      input_template = (
        input_transformer.value.input_template
      )
    }
  }


  # ==========================================================
  # Dead Letter Queue
  # ==========================================================

  dynamic "dead_letter_config" {
    for_each = (
      each.value.dead_letter_arn != null
      ? [each.value.dead_letter_arn]
      : []
    )

    content {
      arn = dead_letter_config.value
    }
  }


  # ==========================================================
  # Retry Policy
  # ==========================================================

  dynamic "retry_policy" {
    for_each = (
      each.value.maximum_event_age_in_seconds != null ||
      each.value.maximum_retry_attempts != null
      ? [1]
      : []
    )

    content {
      maximum_event_age_in_seconds = (
        each.value.maximum_event_age_in_seconds
      )

      maximum_retry_attempts = (
        each.value.maximum_retry_attempts
      )
    }
  }


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = contains(
        keys(var.rules),
        each.value.rule_key
      )

      error_message = "Each EventBridge target rule_key must reference an existing key in rules."
    }

    precondition {
      condition = (
        !var.validate_target_input_exclusivity ||
        length(
          compact([
            each.value.input != null
            ? "input"
            : "",

            each.value.input_path != null
            ? "input_path"
            : "",

            each.value.input_transformer != null
            ? "input_transformer"
            : "",
          ])
        ) <= 1
      )

      error_message = "EventBridge target input, input_path, and input_transformer are mutually exclusive."
    }

    precondition {
      condition = (
        each.value.maximum_event_age_in_seconds == null ||
        (
          each.value.maximum_event_age_in_seconds >= 60 &&
          each.value.maximum_event_age_in_seconds <= 86400
        )
      )

      error_message = "maximum_event_age_in_seconds must be between 60 and 86400."
    }

    precondition {
      condition = (
        each.value.maximum_retry_attempts == null ||
        (
          each.value.maximum_retry_attempts >= 0 &&
          each.value.maximum_retry_attempts <= 185
        )
      )

      error_message = "maximum_retry_attempts must be between 0 and 185."
    }
  }
}