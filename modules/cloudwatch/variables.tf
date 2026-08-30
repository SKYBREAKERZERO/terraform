# ============================================================
# CloudWatch - General
# ============================================================

variable "project_name" {
  description = "Project name used for resource naming and tags."
  type        = string

  validation {
    condition = (
      length(trimspace(var.project_name)) > 0
    )

    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition = (
      length(trimspace(var.environment)) > 0
    )

    error_message = "environment must not be empty."
  }
}


# ============================================================
# CloudWatch Logs
# ============================================================

variable "log_group_name" {
  description = "Optional CloudWatch Log Group name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.log_group_name == null ||
      length(trimspace(var.log_group_name)) > 0
    )

    error_message = "log_group_name must be null or a non-empty string."
  }
}

variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition = contains(
      [
        0,
        1,
        3,
        5,
        7,
        14,
        30,
        60,
        90,
        120,
        150,
        180,
        365,
        400,
        545,
        731,
        1096,
        1827,
        2192,
        2557,
        2922,
        3288,
        3653,
      ],
      var.log_retention_in_days
    )

    error_message = "log_retention_in_days must be a valid CloudWatch Logs retention value."
  }
}

variable "log_kms_key_id" {
  description = "Optional KMS key ARN used to encrypt the CloudWatch Log Group."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.log_kms_key_id == null ||
      length(trimspace(var.log_kms_key_id)) > 0
    )

    error_message = "log_kms_key_id must be null or a non-empty string."
  }
}


# ============================================================
# CloudWatch Metric Alarm
# ============================================================

variable "alarm_enabled" {
  description = "Whether a CloudWatch Metric Alarm is created."
  type        = bool
  default     = true
}

variable "alarm_name" {
  description = "Optional CloudWatch alarm name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.alarm_name == null ||
      length(trimspace(var.alarm_name)) > 0
    )

    error_message = "alarm_name must be null or a non-empty string."
  }
}

variable "alarm_description" {
  description = "Description for the CloudWatch alarm."
  type        = string
  default     = "Managed by Terraform"
}

variable "alarm_namespace" {
  description = "CloudWatch metric namespace."
  type        = string
  default     = "Custom/AWSEnterpriseLab"

  validation {
    condition = (
      length(trimspace(var.alarm_namespace)) > 0
    )

    error_message = "alarm_namespace must not be empty."
  }
}

variable "alarm_metric_name" {
  description = "Metric name monitored by the CloudWatch alarm."
  type        = string
  default     = "HealthStatus"

  validation {
    condition = (
      length(trimspace(var.alarm_metric_name)) > 0
    )

    error_message = "alarm_metric_name must not be empty."
  }
}

variable "alarm_statistic" {
  description = "Statistic used by the CloudWatch alarm."
  type        = string
  default     = "Average"

  validation {
    condition = contains(
      [
        "Average",
        "Sum",
        "Minimum",
        "Maximum",
        "SampleCount",
      ],
      var.alarm_statistic
    )

    error_message = "alarm_statistic must be Average, Sum, Minimum, Maximum, or SampleCount."
  }
}

variable "alarm_period" {
  description = "Metric evaluation period in seconds."
  type        = number
  default     = 60

  validation {
    condition = (
      var.alarm_period >= 10 &&
      floor(var.alarm_period) == var.alarm_period
    )

    error_message = "alarm_period must be an integer of at least 10 seconds."
  }
}

variable "alarm_evaluation_periods" {
  description = "Number of periods used to evaluate the alarm."
  type        = number
  default     = 1

  validation {
    condition = (
      var.alarm_evaluation_periods >= 1 &&
      floor(var.alarm_evaluation_periods) == var.alarm_evaluation_periods
    )

    error_message = "alarm_evaluation_periods must be a positive integer."
  }
}

variable "alarm_datapoints_to_alarm" {
  description = "Number of breaching datapoints required to trigger the alarm."
  type        = number
  default     = 1

  validation {
    condition = (
      var.alarm_datapoints_to_alarm >= 1 &&
      floor(var.alarm_datapoints_to_alarm) == var.alarm_datapoints_to_alarm
    )

    error_message = "alarm_datapoints_to_alarm must be a positive integer."
  }
}

variable "alarm_threshold" {
  description = "Threshold used by the CloudWatch alarm."
  type        = number
  default     = 1
}

variable "alarm_comparison_operator" {
  description = "Comparison operator used by the alarm."
  type        = string
  default     = "GreaterThanOrEqualToThreshold"

  validation {
    condition = contains(
      [
        "GreaterThanOrEqualToThreshold",
        "GreaterThanThreshold",
        "LessThanThreshold",
        "LessThanOrEqualToThreshold",
      ],
      var.alarm_comparison_operator
    )

    error_message = "alarm_comparison_operator contains an unsupported value."
  }
}

variable "alarm_treat_missing_data" {
  description = "How missing metric data is handled."
  type        = string
  default     = "missing"

  validation {
    condition = contains(
      [
        "breaching",
        "notBreaching",
        "ignore",
        "missing",
      ],
      var.alarm_treat_missing_data
    )

    error_message = "alarm_treat_missing_data must be breaching, notBreaching, ignore, or missing."
  }
}

variable "alarm_unit" {
  description = "Optional CloudWatch metric unit."
  type        = string
  default     = null
  nullable    = true
}

variable "alarm_dimensions" {
  description = "Dimensions associated with the CloudWatch metric."
  type        = map(string)
  default     = {}
}


# ============================================================
# CloudWatch Alarm Actions
# ============================================================

variable "alarm_actions_enabled" {
  description = "Whether alarm actions are enabled."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "ARNs executed when the alarm enters ALARM state."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "ARNs executed when the alarm returns to OK state."
  type        = list(string)
  default     = []
}

variable "insufficient_data_actions" {
  description = "ARNs executed when the alarm enters INSUFFICIENT_DATA state."
  type        = list(string)
  default     = []
}


# ============================================================
# CloudWatch Dashboard
# ============================================================

variable "dashboard_enabled" {
  description = "Whether a CloudWatch dashboard is created."
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Optional CloudWatch dashboard name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.dashboard_name == null ||
      length(trimspace(var.dashboard_name)) > 0
    )

    error_message = "dashboard_name must be null or a non-empty string."
  }
}

variable "dashboard_period" {
  description = "Default metric period used in the dashboard."
  type        = number
  default     = 60

  validation {
    condition = (
      var.dashboard_period >= 1 &&
      floor(var.dashboard_period) == var.dashboard_period
    )

    error_message = "dashboard_period must be a positive integer."
  }
}


# ============================================================
# CloudWatch Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to supported CloudWatch resources."
  type        = map(string)
  default     = {}
}