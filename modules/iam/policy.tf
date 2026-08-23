# ============================================================
# SSM Policy Document
# ============================================================

data "aws_iam_policy_document" "ssm" {
  statement {
    sid    = "SSMInstanceManagement"
    effect = "Allow"

    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:PutInventory",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "SSMMessages"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EC2Messages"
    effect = "Allow"

    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }
}


# ============================================================
# SSM Managed Policy
# ============================================================

resource "aws_iam_policy" "ssm" {
  count = var.enable_ssm ? 1 : 0

  name        = "${local.name_prefix}-ssm-core"
  description = "SSM permissions for application EC2 instances"

  policy = data.aws_iam_policy_document.ssm.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ssm-core"
      Role = "instance-management"
    }
  )
}


# ============================================================
# Attach SSM Policy
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ssm[0].arn
}


# ============================================================
# CloudWatch Agent Policy Document
# ============================================================

data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DescribeEC2"
    effect = "Allow"

    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeVolumes"
    ]

    resources = ["*"]
  }
}


# ============================================================
# CloudWatch Agent Managed Policy
# ============================================================

resource "aws_iam_policy" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name        = "${local.name_prefix}-cloudwatch-agent"
  description = "CloudWatch Agent permissions for application EC2 instances"

  policy = data.aws_iam_policy_document.cloudwatch_agent.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cloudwatch-agent"
      Role = "observability"
    }
  )
}


# ============================================================
# Attach CloudWatch Agent Policy
# ============================================================

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.cloudwatch_agent[0].arn
}