data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid    = "EC2AssumeRole"
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name        = "${local.name_prefix}-ec2-role"
  description = "IAM role for private application EC2 instances"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-role"
      Role = "application"
    }
  )
}