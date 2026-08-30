# ============================================================
# CloudWatch - Locals
# ============================================================

locals {
  log_group_name = (
    var.log_group_name != null
    ? var.log_group_name
    : "/aws/${var.project_name}/${var.environment}/application"
  )

  alarm_name = (
    var.alarm_name != null
    ? var.alarm_name
    : "${var.project_name}-${var.environment}-alarm"
  )

  dashboard_name = (
    var.dashboard_name != null
    ? var.dashboard_name
    : "${var.project_name}-${var.environment}-dashboard"
  )
}


# ============================================================
# CloudWatch Log Group
# ============================================================

resource "aws_cloudwatch_log_group" "this" {
  name = local.log_group_name

  retention_in_days = var.log_retention_in_days

  kms_key_id = var.log_kms_key_id

  tags = merge(
    var.common_tags,
    {
      Name      = local.log_group_name
      Component = "observability"
      Service   = "cloudwatch"
    }
  )
}


# ============================================================
# CloudWatch Metric Alarm
# ============================================================

resource "aws_cloudwatch_metric_alarm" "this" {
  count = (
    var.alarm_enabled
    ? 1
    : 0
  )

  alarm_name        = local.alarm_name
  alarm_description = var.alarm_description

  namespace   = var.alarm_namespace
  metric_name = var.alarm_metric_name

  statistic = var.alarm_statistic

  period = var.alarm_period

  evaluation_periods = (
    var.alarm_evaluation_periods
  )

  datapoints_to_alarm = (
    var.alarm_datapoints_to_alarm
  )

  threshold = var.alarm_threshold

  comparison_operator = (
    var.alarm_comparison_operator
  )

  treat_missing_data = (
    var.alarm_treat_missing_data
  )

  unit = var.alarm_unit

  dimensions = var.alarm_dimensions

  actions_enabled = (
    var.alarm_actions_enabled
  )

  alarm_actions = (
    var.alarm_actions
  )

  ok_actions = (
    var.ok_actions
  )

  insufficient_data_actions = (
    var.insufficient_data_actions
  )

  tags = merge(
    var.common_tags,
    {
      Name      = local.alarm_name
      Component = "observability"
      Service   = "cloudwatch"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        var.alarm_datapoints_to_alarm
        <= var.alarm_evaluation_periods
      )

      error_message = "alarm_datapoints_to_alarm must be less than or equal to alarm_evaluation_periods."
    }

    precondition {
      condition = (
        var.alarm_period >= 10
      )

      error_message = "alarm_period must be at least 10 seconds."
    }
  }
}


# ============================================================
# CloudWatch Dashboard
# ============================================================

resource "aws_cloudwatch_dashboard" "this" {
  count = (
    var.dashboard_enabled
    ? 1
    : 0
  )

  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = local.alarm_name
          view   = "timeSeries"
          region = data.aws_region.current.name

          period = var.dashboard_period

          stat = var.alarm_statistic

          metrics = [
            concat(
              [
                var.alarm_namespace,
                var.alarm_metric_name,
              ],
              flatten([
                for key, value in var.alarm_dimensions : [
                  key,
                  value,
                ]
              ])
            )
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          title  = "Application Logs"
          region = data.aws_region.current.name

          query = join(
            "\n",
            [
              "SOURCE '${aws_cloudwatch_log_group.this.name}'",
              "| fields @timestamp, @message",
              "| sort @timestamp desc",
              "| limit 20",
            ]
          )

          view = "table"
        }
      }
    ]
  })
}


# ============================================================
# Current AWS Region
# ============================================================

data "aws_region" "current" {}