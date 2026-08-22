# ============================================================
# NAT Gateway - Target Public Subnets
# ============================================================

locals {
  nat_gateway_subnets = var.nat_gateway_mode == "none" ? {} : (
    var.nat_gateway_mode == "single" ? {
      (sort(keys(var.public_subnets))[0]) = var.public_subnets[sort(keys(var.public_subnets))[0]]
    } : var.public_subnets
  )
}


# ============================================================
# Elastic IPs for NAT Gateways
# ============================================================

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_subnets

  domain = "vpc"

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-nat-eip-${each.key}"
      Type = "nat-eip"
    }
  )
}


# ============================================================
# NAT Gateways
# ============================================================

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  connectivity_type = "public"

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-nat-${each.key}"
      Type = "nat-gateway"
      AZ   = each.value.availability_zone
    }
  )

  depends_on = [
    aws_internet_gateway.this
  ]

  lifecycle {
    precondition {
      condition     = var.create_internet_gateway
      error_message = "A public NAT Gateway requires create_internet_gateway to be true."
    }
  }
}