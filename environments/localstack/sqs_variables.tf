# ============================================================
# SQS
# ============================================================

variable "sqs_enabled" {
  description = "Whether SQS resources are created in this environment."
  type        = bool
  default     = true
}

variable "sqs_queue_name" {
  description = "Optional SQS queue name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.sqs_queue_name == null ||
      length(trimspace(var.sqs_queue_name)) > 0
    )

    error_message = "sqs_queue_name must be null or a non-empty string."
  }
}


# ============================================================
# SQS - FIFO
# ============================================================

variable "sqs_fifo_queue" {
  description = "Whether the SQS queue is FIFO."
  type        = bool
  default     = false
}

variable "sqs_content_based_deduplication" {
  description = "Whether content-based deduplication is enabled for FIFO queues."
  type        = bool
  default     = false
}


# ============================================================
# SQS - Delivery
# ============================================================

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for SQS messages."
  type        = number
  default     = 30

  validation {
    condition = (
      var.sqs_visibility_timeout_seconds >= 0 &&
      var.sqs_visibility_timeout_seconds <= 43200
    )

    error_message = "sqs_visibility_timeout_seconds must be between 0 and 43200."
  }
}

variable "sqs_message_retention_seconds" {
  description = "How long SQS retains messages."
  type        = number
  default     = 345600

  validation {
    condition = (
      var.sqs_message_retention_seconds >= 60 &&
      var.sqs_message_retention_seconds <= 1209600
    )

    error_message = "sqs_message_retention_seconds must be between 60 and 1209600."
  }
}

variable "sqs_receive_wait_time_seconds" {
  description = "Long polling wait time for SQS receives."
  type        = number
  default     = 20

  validation {
    condition = (
      var.sqs_receive_wait_time_seconds >= 0 &&
      var.sqs_receive_wait_time_seconds <= 20
    )

    error_message = "sqs_receive_wait_time_seconds must be between 0 and 20."
  }
}

variable "sqs_delay_seconds" {
  description = "Default delivery delay for SQS messages."
  type        = number
  default     = 0

  validation {
    condition = (
      var.sqs_delay_seconds >= 0 &&
      var.sqs_delay_seconds <= 900
    )

    error_message = "sqs_delay_seconds must be between 0 and 900."
  }
}

variable "sqs_max_message_size" {
  description = "Maximum SQS message size in bytes."
  type        = number
  default     = 262144

  validation {
    condition = (
      var.sqs_max_message_size >= 1024 &&
      var.sqs_max_message_size <= 262144
    )

    error_message = "sqs_max_message_size must be between 1024 and 262144 bytes."
  }
}


# ============================================================
# SQS - Encryption
# ============================================================

variable "sqs_kms_master_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the SQS queue."
  type        = string
  default     = null
  nullable    = true
}


# ============================================================
# SQS - Dead Letter Queue
# ============================================================

variable "sqs_dead_letter_queue_enabled" {
  description = "Whether a dead-letter queue is created."
  type        = bool
  default     = true
}

variable "sqs_max_receive_count" {
  description = "Number of receives before a message is moved to the DLQ."
  type        = number
  default     = 5

  validation {
    condition = (
      var.sqs_max_receive_count >= 1 &&
      var.sqs_max_receive_count <= 1000
    )

    error_message = "sqs_max_receive_count must be between 1 and 1000."
  }
}