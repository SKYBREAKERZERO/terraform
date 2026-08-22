# ============================================================
# Public Subnets
# ============================================================

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "public"
    }
  )
}


# ============================================================
# Private Application Subnets
# ============================================================

resource "aws_subnet" "private_app" {
  for_each = var.private_app_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = false

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "private-app"
    }
  )
}


# ============================================================
# Private Database Subnets
# ============================================================

resource "aws_subnet" "private_db" {
  for_each = var.private_db_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = false

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-${each.key}"
      Tier = "private-db"
    }
  )
}