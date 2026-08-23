resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(
    local.common_tags,
    {
        Name = "${local.name_prefix}-ec2-instance-profile"
        Role = "application"
    }
  )
}