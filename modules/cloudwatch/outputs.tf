# ============================================================
# CloudWatch Log Group
# ============================================================

output "log_group_name" {
  description = "CloudWatch Log Group name."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch Log Group ARN."
  value       = aws_cloudwatch_log_group.this.arn
}


# ============================================================
# CloudWatch Metric Alarm
# ============================================================

output "alarm_name" {
  description = "CloudWatch Metric Alarm name."

  value = (
    var.alarm_enabled
    ? aws_cloudwatch_metric_alarm.this[0].alarm_name
    : null
  )
}

output "alarm_arn" {
  description = "CloudWatch Metric Alarm ARN."

  value = (
    var.alarm_enabled
    ? aws_cloudwatch_metric_alarm.this[0].arn
    : null
  )
}


# ============================================================
# CloudWatch Dashboard
# ============================================================

output "dashboard_name" {
  description = "CloudWatch Dashboard name."

  value = (
    var.dashboard_enabled
    ? aws_cloudwatch_dashboard.this[0].dashboard_name
    : null
  )
}

output "dashboard_arn" {
  description = "CloudWatch Dashboard ARN."

  value = (
    var.dashboard_enabled
    ? aws_cloudwatch_dashboard.this[0].dashboard_arn
    : null
  )
}


# ============================================================
# CloudWatch Configuration
# ============================================================

output "metric_namespace" {
  description = "CloudWatch metric namespace used by the alarm."
  value       = var.alarm_namespace
}

output "metric_name" {
  description = "CloudWatch metric name used by the alarm."
  value       = var.alarm_metric_name
}

output "metric_dimensions" {
  description = "CloudWatch metric dimensions used by the alarm."
  value       = var.alarm_dimensions
}