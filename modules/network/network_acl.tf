# ============================================================
# Public Network ACL
# ============================================================

resource "aws_network_acl" "public" {
  count = var.enable_custom_network_acls ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for subnet in aws_subnet.public : subnet.id]

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-public-nacl"
      Type = "network-acl"
      Tier = "public"
    }
  )
}


# ============================================================
# Public Network ACL - Ingress Rules
# ============================================================

resource "aws_network_acl_rule" "public_ingress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.public_nacl_ingress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.public[0].id

  rule_number = each.value.rule_number
  egress      = false
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}


# ============================================================
# Public Network ACL - Egress Rules
# ============================================================

resource "aws_network_acl_rule" "public_egress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.public_nacl_egress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.public[0].id

  rule_number = each.value.rule_number
  egress      = true
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}


# ============================================================
# Private Application Network ACL
# ============================================================

resource "aws_network_acl" "private_app" {
  count = var.enable_custom_network_acls ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for subnet in aws_subnet.private_app : subnet.id]

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-private-app-nacl"
      Type = "network-acl"
      Tier = "private-app"
    }
  )
}


# ============================================================
# Private Application Network ACL - Ingress Rules
# ============================================================

resource "aws_network_acl_rule" "private_app_ingress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.private_app_nacl_ingress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.private_app[0].id

  rule_number = each.value.rule_number
  egress      = false
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}


# ============================================================
# Private Application Network ACL - Egress Rules
# ============================================================

resource "aws_network_acl_rule" "private_app_egress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.private_app_nacl_egress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.private_app[0].id

  rule_number = each.value.rule_number
  egress      = true
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}


# ============================================================
# Private Database Network ACL
# ============================================================

resource "aws_network_acl" "private_db" {
  count = var.enable_custom_network_acls ? 1 : 0

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for subnet in aws_subnet.private_db : subnet.id]

  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-private-db-nacl"
      Type = "network-acl"
      Tier = "private-db"
    }
  )
}


# ============================================================
# Private Database Network ACL - Ingress Rules
# ============================================================

resource "aws_network_acl_rule" "private_db_ingress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.private_db_nacl_ingress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.private_db[0].id

  rule_number = each.value.rule_number
  egress      = false
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}


# ============================================================
# Private Database Network ACL - Egress Rules
# ============================================================

resource "aws_network_acl_rule" "private_db_egress" {
  for_each = var.enable_custom_network_acls ? {
    for rule in var.private_db_nacl_egress_rules :
    tostring(rule.rule_number) => rule
  } : {}

  network_acl_id = aws_network_acl.private_db[0].id

  rule_number = each.value.rule_number
  egress      = true
  protocol    = each.value.protocol
  rule_action = each.value.rule_action
  cidr_block  = each.value.cidr_block

  from_port = each.value.from_port
  to_port   = each.value.to_port
}