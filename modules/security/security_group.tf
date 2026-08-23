resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for private application EC2 instances"
  vpc_id      = var.vpc_id

  # Rules are managed as standalone resources in
  # security_group_rules.tf.
  revoke_rules_on_delete = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-sg"
      Tier = "private-app"
      Role = "application"
    }
  )
}