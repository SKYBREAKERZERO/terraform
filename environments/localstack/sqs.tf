module "sqs" {
  source = "../../modules/sqs"

  project_name = var.project_name
  environment  = var.environment

  queue_name = var.sqs_queue_name

  fifo_queue                  = var.sqs_fifo_queue
  content_based_deduplication = var.sqs_content_based_deduplication

  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  delay_seconds              = var.sqs_delay_seconds
  max_message_size           = var.sqs_max_message_size

  kms_master_key_id = var.sqs_kms_master_key_id

  dead_letter_queue_enabled = var.sqs_dead_letter_queue_enabled
  max_receive_count         = var.sqs_max_receive_count

  common_tags = local.common_tags
}