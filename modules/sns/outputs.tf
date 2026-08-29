# ============================================================
# SNS Topic
# ============================================================

output "topic_id" {
  description = "SNS topic ID."
  value       = aws_sns_topic.this.id
}

output "topic_arn" {
  description = "SNS topic ARN."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "SNS topic name."
  value       = aws_sns_topic.this.name
}

# ============================================================
# SNS Subscriptions
# ============================================================

output "subscription_arns" {
  description = "Map of SNS subscription ARNs."

  value = {
    for key, subscription in aws_sns_topic_subscription.this :
    key => subscription.arn
  }
}

output "subscription_protocols" {
  description = "Map of SNS subscription protocols."

  value = {
    for key, subscription in aws_sns_topic_subscription.this :
    key => subscription.protocol
  }
}

output "subscription_endpoints" {
  description = "Map of SNS subscription endpoints."

  value = {
    for key, subscription in aws_sns_topic_subscription.this :
    key => subscription.endpoint
  }
}