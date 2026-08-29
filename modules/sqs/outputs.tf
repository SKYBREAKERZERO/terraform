# ============================================================
# SQS - Main Queue
# ============================================================

output "queue_id" {
  description = "SQS queue ID."
  value       = aws_sqs_queue.this.id
}

output "queue_arn" {
  description = "SQS queue ARN."
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "SQS queue URL."
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "SQS queue name."
  value       = aws_sqs_queue.this.name
}


# ============================================================
# SQS - Dead Letter Queue
# ============================================================

output "dlq_id" {
  description = "Dead-letter queue ID."
  value = (
    var.dead_letter_queue_enabled
    ? aws_sqs_queue.dlq[0].id
    : null
  )
}

output "dlq_arn" {
  description = "Dead-letter queue ARN."
  value = (
    var.dead_letter_queue_enabled
    ? aws_sqs_queue.dlq[0].arn
    : null
  )
}

output "dlq_url" {
  description = "Dead-letter queue URL."
  value = (
    var.dead_letter_queue_enabled
    ? aws_sqs_queue.dlq[0].url
    : null
  )
}

output "dlq_name" {
  description = "Dead-letter queue name."
  value = (
    var.dead_letter_queue_enabled
    ? aws_sqs_queue.dlq[0].name
    : null
  )
}