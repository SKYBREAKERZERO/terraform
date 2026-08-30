# ============================================================
# EventBridge - General
# ============================================================

variable "project_name" {
  description = "Project name used for EventBridge resource naming."
  type        = string

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}


# ============================================================
# EventBridge - Event Bus
# ============================================================

variable "create_custom_event_bus" {
  description = "Whether to create a custom EventBridge event bus. If false, the default event bus is used."
  type        = bool
  default     = true
}

variable "event_bus_name" {
  description = "Optional custom EventBridge event bus name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.event_bus_name == null ||
      (
        length(trimspace(var.event_bus_name)) > 0 &&
        length(var.event_bus_name) <= 256 &&
        can(regex(
          "^[A-Za-z0-9._-]+$",
          var.event_bus_name
        ))
      )
    )

    error_message = "event_bus_name must be null or contain only letters, numbers, '.', '_', and '-', with a maximum length of 256 characters."
  }
}


# ============================================================
# EventBridge - Rules
# ============================================================

variable "rules" {
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
      for key, rule in var.rules :
      (
        length(trimspace(key)) > 0 &&
        length(trimspace(rule.event_pattern)) > 0
      )
    ])

    error_message = "Each EventBridge rule must have a non-empty logical key and event_pattern."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) :
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

    error_message = "Rule names must be null or contain only letters, numbers, '.', '_', and '-', with a maximum length of 64 characters."
  }
}


# ============================================================
# EventBridge - Targets
# ============================================================

variable "targets" {
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
      for key, target in var.targets :
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
      for target in values(var.targets) :
      (
        target.target_id == null ||
        length(trimspace(target.target_id)) > 0
      )
    ])

    error_message = "target_id must be null or a non-empty string."
  }

  validation {
    condition = alltrue([
      for target in values(var.targets) :
      (
        target.role_arn == null ||
        length(trimspace(target.role_arn)) > 0
      )
    ])

    error_message = "role_arn must be null or a non-empty string."
  }

  validation {
    condition = alltrue([
      for target in values(var.targets) :
      (
        target.dead_letter_arn == null ||
        length(trimspace(target.dead_letter_arn)) > 0
      )
    ])

    error_message = "dead_letter_arn must be null or a non-empty string."
  }
}


# ============================================================
# EventBridge - Target Input
# ============================================================

variable "validate_target_input_exclusivity" {
  description = "Whether target input, input_path, and input_transformer are required to be mutually exclusive."
  type        = bool
  default     = true
}


# ============================================================
# EventBridge - Retry Policy
# ============================================================

variable "default_maximum_event_age_in_seconds" {
  description = "Default maximum age of an event before EventBridge stops retrying delivery."
  type        = number
  default     = 86400

  validation {
    condition = (
      var.default_maximum_event_age_in_seconds >= 60 &&
      var.default_maximum_event_age_in_seconds <= 86400
    )

    error_message = "default_maximum_event_age_in_seconds must be between 60 and 86400."
  }
}

variable "default_maximum_retry_attempts" {
  description = "Default maximum number of EventBridge target delivery retry attempts."
  type        = number
  default     = 185

  validation {
    condition = (
      var.default_maximum_retry_attempts >= 0 &&
      var.default_maximum_retry_attempts <= 185
    )

    error_message = "default_maximum_retry_attempts must be between 0 and 185."
  }
}


# ============================================================
# EventBridge - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to EventBridge resources."
  type        = map(string)
  default     = {}
}