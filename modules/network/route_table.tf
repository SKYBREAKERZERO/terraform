# ============================================================
# NAT Gateway Mapping
# ============================================================

locals {
  public_subnet_key_by_az = {
    for key, subnet in var.public_subnets :
    subnet.availability_zone => key
  }

  single_nat_gateway_key = var.nat_gateway_mode == "single" ? sort(keys(local.nat_gateway_subnets))[0] : null

  private_app_nat_gateway_key = var.nat_gateway_mode == "none" ? {} : {
    for key, subnet in var.private_app_subnets :
    key => var.nat_gateway_mode == "single"
    ? local.single_nat_gateway_key
    : lookup(
      local.public_subnet_key_by_az,
      subnet.availability_zone,
      null
    )
  }
}


# ============================================================
# Public Route Table
# ============================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-public-rt"
      Type = "route-table"
      Tier = "public"
    }
  )
}


# ============================================================
# Public Internet Route
# ============================================================

resource "aws_route" "public_internet" {
  count = var.create_internet_gateway ? 1 : 0

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}


# ============================================================
# Public Route Table Associations
# ============================================================

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# ============================================================
# Private Application Route Tables
# ============================================================

resource "aws_route_table" "private_app" {
  for_each = var.private_app_subnets

  vpc_id = aws_vpc.this.id

  lifecycle {
    precondition {
      condition = (
        var.nat_gateway_mode != "one-per-az" ||
        contains(
          keys(local.public_subnet_key_by_az),
          each.value.availability_zone
        )
      )

      error_message = "Each private application subnet must have a public subnet in the same Availability Zone when nat_gateway_mode is one-per-az."
    }
  }

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-${each.key}-rt"
      Type = "route-table"
      Tier = "private-app"
    }
  )
}


# ============================================================
# Private Application NAT Routes
# ============================================================

resource "aws_route" "private_app_nat" {
  for_each = var.nat_gateway_mode == "none" ? {} : aws_route_table.private_app

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.private_app_nat_gateway_key[each.key]].id
}


# ============================================================
# Private Application Route Table Associations
# ============================================================

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}


# ============================================================
# Private Database Route Tables
# ============================================================

resource "aws_route_table" "private_db" {
  for_each = var.private_db_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-${each.key}-rt"
      Type = "route-table"
      Tier = "private-db"
    }
  )
}


# ============================================================
# Private Database Route Table Associations
# ============================================================

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}