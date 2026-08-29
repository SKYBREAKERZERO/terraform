locals {
  base_topic_name = (
    var.topic_name != null
    ? var.topic_name
    : "${var.project_name}-${var.environment}-alerts"
  )

  topic_name = (
    var.fifo_topic &&
    !endswith(local.base_topic_name, ".fifo")
    ? "${local.base_topic_name}.fifo"
    : local.base_topic_name
  )
}

# ============================================================
# SNS Topic
# ============================================================

resource "aws_sns_topic" "this" {
  name = local.topic_name

  display_name = var.display_name

  kms_master_key_id = var.kms_master_key_id

  fifo_topic = var.fifo_topic

  content_based_deduplication = (
    var.fifo_topic
    ? var.content_based_deduplication
    : false
  )

  tags = merge(
    var.common_tags,
    {
      Name      = local.topic_name
      Component = "messaging"
      Service   = "sns"
    }
  )
}

# ============================================================
# SNS Subscriptions
# ============================================================

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn = aws_sns_topic.this.arn

  protocol = each.value.protocol
  endpoint = each.value.endpoint
}