# ============================================================
# EventBridge - General
# ============================================================

variable "eventbridge_enabled" {
  description = "Whether EventBridge resources are created in this environment."
  type        = bool
  default     = true
}


# ============================================================
# EventBridge - Event Bus
# ============================================================

variable "eventbridge_create_custom_event_bus" {
  description = "Whether to create a custom EventBridge event bus."
  type        = bool
  default     = true
}

variable "eventbridge_event_bus_name" {
  description = "Optional custom EventBridge event bus name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.eventbridge_event_bus_name == null ||
      (
        length(trimspace(var.eventbridge_event_bus_name)) > 0 &&
        length(var.eventbridge_event_bus_name) <= 256 &&
        can(regex(
          "^[A-Za-z0-9._-]+$",
          var.eventbridge_event_bus_name
        ))
      )
    )

    error_message = "eventbridge_event_bus_name must be null or contain only letters, numbers, '.', '_', and '-', with a maximum length of 256 characters."
  }
}


# ============================================================
# EventBridge - Rules
# ============================================================

variable "eventbridge_rules" {
  description = "EventBridge rules keyed by logical rule name."

  type = map(object({
    name = optional(
      string
    )

    description = optional(
      string
    )

    event_pattern = string

    enabled = optional(
      bool,
      true
    )

    tags = optional(
      map(string),
      {}
    )
  }))

  default = {}

  validation {
    condition = alltrue([
      for key, rule in var.eventbridge_rules :
      (
        length(trimspace(key)) > 0 &&
        length(trimspace(rule.event_pattern)) > 0
      )
    ])

    error_message = "Each EventBridge rule must have a non-empty logical key and event_pattern."
  }

  validation {
    condition = alltrue([
      for rule in values(var.eventbridge_rules) :
      (
        rule.name == null ||
        (
          length(trimspace(rule.name)) > 0 &&
          length(rule.name) <= 64 &&
          can(regex(
            "^[A-Za-z0-9._-]+$",
            rule.name
          ))
        )
      )
    ])

    error_message = "EventBridge rule names must be null or contain only letters, numbers, '.', '_', and '-', with a maximum length of 64 characters."
  }
}


# ============================================================
# EventBridge - Targets
# ============================================================

variable "eventbridge_targets" {
  description = "EventBridge targets keyed by logical target name."

  type = map(object({
    rule_key = string

    arn = string

    target_id = optional(
      string
    )

    role_arn = optional(
      string
    )

    input = optional(
      string
    )

    input_path = optional(
      string
    )

    input_transformer = optional(object({
      input_paths = optional(
        map(string),
        {}
      )

      input_template = string
    }))

    dead_letter_arn = optional(
      string
    )

    maximum_event_age_in_seconds = optional(
      number,
      86400
    )

    maximum_retry_attempts = optional(
      number,
      185
    )
  }))

  default = {}

  validation {
    condition = alltrue([
      for key, target in var.eventbridge_targets :
      (
        length(trimspace(key)) > 0 &&
        length(trimspace(target.rule_key)) > 0 &&
        length(trimspace(target.arn)) > 0
      )
    ])

    error_message = "Each EventBridge target must have a non-empty logical key, rule_key, and arn."
  }

  validation {
    condition = alltrue([
      for target in values(var.eventbridge_targets) :
      (
        target.maximum_event_age_in_seconds == null ||
        (
          target.maximum_event_age_in_seconds >= 60 &&
          target.maximum_event_age_in_seconds <= 86400
        )
      )
    ])

    error_message = "maximum_event_age_in_seconds must be between 60 and 86400."
  }

  validation {
    condition = alltrue([
      for target in values(var.eventbridge_targets) :
      (
        target.maximum_retry_attempts == null ||
        (
          target.maximum_retry_attempts >= 0 &&
          target.maximum_retry_attempts <= 185
        )
      )
    ])

    error_message = "maximum_retry_attempts must be between 0 and 185."
  }
}


# ============================================================
# EventBridge - Target Validation
# ============================================================

variable "eventbridge_validate_target_input_exclusivity" {
  description = "Whether input, input_path, and input_transformer must be mutually exclusive."
  type        = bool
  default     = true
}