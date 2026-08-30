# ============================================================
# Step Functions - General
# ============================================================

variable "stepfunctions_enabled" {
  description = "Whether Step Functions resources are created in this environment."
  type        = bool
  default     = true
}

variable "stepfunctions_state_machine_name" {
  description = "Optional Step Functions state machine name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.stepfunctions_state_machine_name == null ||
      (
        length(trimspace(var.stepfunctions_state_machine_name)) > 0 &&
        length(var.stepfunctions_state_machine_name) <= 80
      )
    )

    error_message = "stepfunctions_state_machine_name must be null or a non-empty string with a maximum length of 80 characters."
  }
}


# ============================================================
# Step Functions - Type
# ============================================================

variable "stepfunctions_state_machine_type" {
  description = "Step Functions state machine type."
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      [
        "STANDARD",
        "EXPRESS",
      ],
      var.stepfunctions_state_machine_type
    )

    error_message = "stepfunctions_state_machine_type must be either STANDARD or EXPRESS."
  }
}


# ============================================================
# Step Functions - IAM
# ============================================================

variable "stepfunctions_role_arn" {
  description = "IAM execution role ARN used by the Step Functions state machine."
  type        = string

  validation {
    condition = (
      length(trimspace(var.stepfunctions_role_arn)) > 0 &&
      can(regex(
        "^arn:[^:]+:iam::[0-9]{12}:role/.+$",
        var.stepfunctions_role_arn
      ))
    )

    error_message = "stepfunctions_role_arn must be a valid IAM role ARN."
  }
}


# ============================================================
# Step Functions - Definition
# ============================================================

variable "stepfunctions_definition" {
  description = "Amazon States Language definition for the state machine as a JSON string."
  type        = string

  validation {
    condition = (
      length(trimspace(var.stepfunctions_definition)) > 0 &&
      can(jsondecode(var.stepfunctions_definition))
    )

    error_message = "stepfunctions_definition must contain valid JSON."
  }
}


# ============================================================
# Step Functions - Logging
# ============================================================

variable "stepfunctions_logging_enabled" {
  description = "Whether CloudWatch Logs integration is enabled."
  type        = bool
  default     = false
}

variable "stepfunctions_log_destination" {
  description = "Optional CloudWatch Logs log group ARN used by Step Functions logging."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.stepfunctions_log_destination == null ||
      length(trimspace(var.stepfunctions_log_destination)) > 0
    )

    error_message = "stepfunctions_log_destination must be null or a non-empty string."
  }
}

variable "stepfunctions_log_level" {
  description = "Step Functions execution logging level."
  type        = string
  default     = "ALL"

  validation {
    condition = contains(
      [
        "ALL",
        "ERROR",
        "FATAL",
        "OFF",
      ],
      var.stepfunctions_log_level
    )

    error_message = "stepfunctions_log_level must be ALL, ERROR, FATAL, or OFF."
  }
}

variable "stepfunctions_include_execution_data" {
  description = "Whether execution data is included in Step Functions logs."
  type        = bool
  default     = true
}


# ============================================================
# Step Functions - X-Ray
# ============================================================

variable "stepfunctions_tracing_enabled" {
  description = "Whether AWS X-Ray tracing is enabled."
  type        = bool
  default     = false
}