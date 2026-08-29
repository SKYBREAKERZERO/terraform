locals {
  base_queue_name = (
    var.queue_name != null
    ? var.queue_name
    : "${var.project_name}-${var.environment}-queue"
  )

  queue_name = (
    var.fifo_queue &&
    !endswith(local.base_queue_name, ".fifo")
    ? "${local.base_queue_name}.fifo"
    : local.base_queue_name
  )

  base_dlq_name = (
    var.fifo_queue
    ? trimsuffix(local.queue_name, ".fifo")
    : local.queue_name
  )

  dlq_name = (
    var.fifo_queue
    ? "${local.base_dlq_name}-dlq.fifo"
    : "${local.base_dlq_name}-dlq"
  )
}

resource "aws_sqs_queue" "dlq" {
  count = var.dead_letter_queue_enabled ? 1 : 0

  name = local.dlq_name

  fifo_queue = var.fifo_queue

  content_based_deduplication = (
    var.fifo_queue
    ? var.content_based_deduplication
    : false
  )

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size

  kms_master_key_id = var.kms_master_key_id

  tags = merge(
    var.common_tags,
    {
      Name      = local.dlq_name
      Component = "messaging"
      Service   = "sqs"
      QueueType = "dlq"
    }
  )

  lifecycle {
    precondition {
      condition = (
        !var.content_based_deduplication ||
        var.fifo_queue
      )

      error_message = "content_based_deduplication requires fifo_queue = true."
    }
  }
}

resource "aws_sqs_queue" "this" {
  name = local.queue_name

  fifo_queue = var.fifo_queue

  content_based_deduplication = (
    var.fifo_queue
    ? var.content_based_deduplication
    : false
  )

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size

  kms_master_key_id = var.kms_master_key_id

  redrive_policy = (
    var.dead_letter_queue_enabled
    ? jsonencode({
        deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
        maxReceiveCount     = var.max_receive_count
      })
    : null
  )

  tags = merge(
    var.common_tags,
    {
      Name      = local.queue_name
      Component = "messaging"
      Service   = "sqs"
      QueueType = "main"
    }
  )

  lifecycle {
    precondition {
      condition = (
        !var.content_based_deduplication ||
        var.fifo_queue
      )

      error_message = "content_based_deduplication requires fifo_queue = true."
    }
  }
}