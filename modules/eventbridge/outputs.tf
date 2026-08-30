# ============================================================
# EventBridge - Event Bus
# ============================================================

output "event_bus_name" {
  description = "EventBridge event bus name."
  value       = local.event_bus_name
}

output "event_bus_arn" {
  description = "ARN of the custom EventBridge event bus. Null when using the default event bus."
  value = (
    var.create_custom_event_bus
    ? aws_cloudwatch_event_bus.this[0].arn
    : null
  )
}

output "custom_event_bus_created" {
  description = "Whether a custom EventBridge event bus was created."
  value       = var.create_custom_event_bus
}


# ============================================================
# EventBridge - Rules
# ============================================================

output "rule_ids" {
  description = "Map of EventBridge rule IDs keyed by logical rule key."

  value = {
    for key, rule in aws_cloudwatch_event_rule.this :
    key => rule.id
  }
}

output "rule_arns" {
  description = "Map of EventBridge rule ARNs keyed by logical rule key."

  value = {
    for key, rule in aws_cloudwatch_event_rule.this :
    key => rule.arn
  }
}

output "rule_names" {
  description = "Map of EventBridge rule names keyed by logical rule key."

  value = {
    for key, rule in aws_cloudwatch_event_rule.this :
    key => rule.name
  }
}

output "rule_states" {
  description = "Map of EventBridge rule states keyed by logical rule key."

  value = {
    for key, rule in aws_cloudwatch_event_rule.this :
    key => rule.state
  }
}


# ============================================================
# EventBridge - Targets
# ============================================================

output "target_ids" {
  description = "Map of EventBridge target IDs keyed by logical target key."

  value = {
    for key, target in aws_cloudwatch_event_target.this :
    key => target.target_id
  }
}

output "target_arns" {
  description = "Map of EventBridge target ARNs keyed by logical target key."

  value = {
    for key, target in aws_cloudwatch_event_target.this :
    key => target.arn
  }
}

output "target_rule_names" {
  description = "Map of EventBridge rule names associated with each target."

  value = {
    for key, target in aws_cloudwatch_event_target.this :
    key => target.rule
  }
}

output "target_role_arns" {
  description = "Map of IAM role ARNs associated with EventBridge targets."

  value = {
    for key, target in aws_cloudwatch_event_target.this :
    key => target.role_arn
  }
}