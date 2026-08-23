resource "aws_vpc_security_group_egress_rule" "app_ipv4" {
  security_group_id = aws_security_group.app.id

  description = "Allow application instances outbound IPv4 traffic"

  ip_protocol = "-1"
  cidr_ipv4   = var.app_egress_cidr_ipv4

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-app-egress-ipv4"
      Tier = "private-app"
      Role = "application-egress"
    }
  )
}