# ============================================================
# SQS - General
# ============================================================

variable "project_name" {
  description = "Project name used for SQS resource naming."
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

variable "queue_name" {
  description = "Optional SQS queue name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.queue_name == null ||
      length(trimspace(var.queue_name)) > 0
    )

    error_message = "queue_name must be null or a non-empty string."
  }
}


# ============================================================
# SQS - FIFO
# ============================================================

variable "fifo_queue" {
  description = "Whether the SQS queue is FIFO."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Whether content-based deduplication is enabled for FIFO queues."
  type        = bool
  default     = false
}


# ============================================================
# SQS - Delivery
# ============================================================

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for received messages."
  type        = number
  default     = 30

  validation {
    condition = (
      var.visibility_timeout_seconds >= 0 &&
      var.visibility_timeout_seconds <= 43200
    )

    error_message = "visibility_timeout_seconds must be between 0 and 43200."
  }
}

variable "message_retention_seconds" {
  description = "How long SQS retains messages."
  type        = number
  default     = 345600

  validation {
    condition = (
      var.message_retention_seconds >= 60 &&
      var.message_retention_seconds <= 1209600
    )

    error_message = "message_retention_seconds must be between 60 and 1209600."
  }
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time."
  type        = number
  default     = 20

  validation {
    condition = (
      var.receive_wait_time_seconds >= 0 &&
      var.receive_wait_time_seconds <= 20
    )

    error_message = "receive_wait_time_seconds must be between 0 and 20."
  }
}

variable "delay_seconds" {
  description = "Default message delivery delay."
  type        = number
  default     = 0

  validation {
    condition = (
      var.delay_seconds >= 0 &&
      var.delay_seconds <= 900
    )

    error_message = "delay_seconds must be between 0 and 900."
  }
}

variable "max_message_size" {
  description = "Maximum message size in bytes."
  type        = number
  default     = 262144

  validation {
    condition = (
      var.max_message_size >= 1024 &&
      var.max_message_size <= 262144
    )

    error_message = "max_message_size must be between 1024 and 262144 bytes."
  }
}


# ============================================================
# SQS - Encryption
# ============================================================

variable "kms_master_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the SQS queue."
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# SQS - Dead Letter Queue
# ============================================================

variable "dead_letter_queue_enabled" {
  description = "Whether a dead-letter queue is created."
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Number of receives before a message is moved to the DLQ."
  type        = number
  default     = 5

  validation {
    condition = (
      var.max_receive_count >= 1 &&
      var.max_receive_count <= 1000
    )

    error_message = "max_receive_count must be between 1 and 1000."
  }
}


# ============================================================
# SQS - Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to SQS resources."
  type        = map(string)
  default     = {}
}