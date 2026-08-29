# ============================================================
# SNS
# ============================================================

variable "sns_enabled" {
  description = "Whether SNS resources are created in this environment."
  type        = bool
  default     = true
}

variable "sns_topic_name" {
  description = "Optional SNS topic name."
  type        = string
  default     = null
  nullable    = true
}

variable "sns_display_name" {
  description = "Optional SNS topic display name."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# SNS - Encryption
# ============================================================

variable "sns_kms_master_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the SNS topic."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# SNS - FIFO
# ============================================================

variable "sns_fifo_topic" {
  description = "Whether the SNS topic is FIFO."
  type        = bool
  default     = false
}

variable "sns_content_based_deduplication" {
  description = "Whether content-based deduplication is enabled for FIFO SNS topics."
  type        = bool
  default     = false
}

# ============================================================
# SNS - Subscriptions
# ============================================================

variable "sns_subscriptions" {
  description = "SNS subscriptions keyed by logical name."

  type = map(object({
    protocol = string
    endpoint = string
  }))

  default = {}

  validation {
    condition = alltrue([
      for subscription in values(var.sns_subscriptions) :
      contains(
        [
          "email",
          "email-json",
          "http",
          "https",
          "lambda",
          "sqs"
        ],
        subscription.protocol
      )
    ])

    error_message = "sns_subscriptions contains an unsupported protocol."
  }
}