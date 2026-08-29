variable "project_name" {
  description = "Project name used for SNS resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "topic_name" {
  description = "SNS topic name."
  type        = string
  default     = null
  nullable    = true
}

variable "display_name" {
  description = "Optional SNS topic display name."
  type        = string
  default     = null
  nullable    = true
}

variable "kms_master_key_id" {
  description = "Optional KMS key ID or ARN used to encrypt the SNS topic."
  type        = string
  default     = null
  nullable    = true
}

variable "fifo_topic" {
  description = "Whether the SNS topic is FIFO."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Whether content-based deduplication is enabled for FIFO topics."
  type        = bool
  default     = false
}

variable "subscriptions" {
  description = "SNS subscriptions keyed by logical name."

  type = map(object({
    protocol = string
    endpoint = string
  }))

  default = {}

  validation {
    condition = alltrue([
      for subscription in values(var.subscriptions) :
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

    error_message = "Unsupported SNS subscription protocol."
  }
}

variable "common_tags" {
  description = "Common tags applied to SNS resources."
  type        = map(string)
  default     = {}
}