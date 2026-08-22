# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  instance_tenancy = var.instance_tenancy

  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-vpc"
      Type = "vpc"
    }
  )
}