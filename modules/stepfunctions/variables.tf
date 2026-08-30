# ============================================================
# Step Functions - General
# ============================================================

variable "project_name" {
  description = "Project name used for Step Functions resource naming."
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

variable "state_machine_name" {
  description = "Optional Step Functions state machine name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.state_machine_name == null ||
      (
        length(trimspace(var.state_machine_name)) > 0 &&
        length(var.state_machine_name) <= 80
      )
    )

    error_message = "state_machine_name must be null or a non-empty string with a maximum length of 80 characters."
  }
}


# ============================================================
# Step Functions - Type
# ============================================================

variable "state_machine_type" {
  description = "Step Functions state machine type."
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains(
      [
        "STANDARD",
        "EXPRESS",
      ],
      var.state_machine_type
    )

    error_message = "state_machine_type must be either STANDARD or EXPRESS."
  }
}


# ============================================================
# Step Functions - IAM
# ============================================================

variable "role_arn" {
  description = "IAM execution role ARN used by the Step Functions state machine."
  type        = string

  validation {
    condition = (
      length(trimspace(var.role_arn)) > 0 &&
      can(regex(
        "^arn:[^:]+:iam::[0-9]{12}:role/.+$",
        var.role_arn
      ))
    )

    error_message = "role_arn must be a valid IAM role ARN."
  }
}


# ============================================================
# Step Functions - ASL Definition
# ============================================================

variable "definition" {
  description = "Amazon States Language definition for the state machine as a JSON string."
  type        = string

  validation {
    condition = (
      length(trimspace(var.definition)) > 0 &&
      can(jsondecode(var.definition))
    )

    error_message = "definition must contain valid JSON."
  }
}


# ============================================================
# Step Functions - Logging
# ============================================================

variable "logging_enabled" {
  description = "Whether CloudWatch Logs integration is enabled."
  type        = bool
  default     = false
}

variable "log_destination" {
  description = "Optional CloudWatch Logs log group ARN used by Step Functions logging."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.log_destination == null ||
      length(trimspace(var.log_destination)) > 0
    )

    error_message = "log_destination must be null or a non-empty string."
  }
}

variable "log_level" {
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
      var.log_level
    )

    error_message = "log_level must be ALL, ERROR, FATAL, or OFF."
  }
}

variable "include_execution_data" {
  description = "Whether execution data is included in Step Functions logs."
  type        = bool
  default     = true
}


# ============================================================
# Step Functions - X-Ray
# ============================================================

variable "tracing_enabled" {
  description = "Whether AWS X-Ray tracing is enabled for the state machine."
  type        = bool
  default     = false
}


# ============================================================
# Step Functions - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to Step Functions resources."
  type        = map(string)
  default     = {}
}