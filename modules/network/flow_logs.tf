# ============================================================
# VPC Flow Logs - CloudWatch Log Group
# ============================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc-flow-logs/${local.name_prefix}"
  retention_in_days = var.flow_log_retention_days

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-logs"
      Type = "vpc-flow-logs"
    }
  )
}


# ============================================================
# VPC Flow Logs - IAM Role
# ============================================================

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-logs-role"
      Type = "iam-role"
    }
  )
}


# ============================================================
# VPC Flow Logs - IAM Policy
# ============================================================

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
      },
      {
        Effect = "Allow"

        Action = [
          "logs:DescribeLogGroups"
        ]

        Resource = "*"
      }
    ]
  })
}


# ============================================================
# VPC Flow Logs
# ============================================================

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = var.flow_log_traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs[0].arn
  max_aggregation_interval = var.flow_log_max_aggregation_interval

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-log"
      Type = "vpc-flow-log"
    }
  )
}