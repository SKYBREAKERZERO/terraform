# ============================================================
# Security
# ============================================================

module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment

  # Security resources are created inside the project VPC.
  vpc_id = module.network.vpc_id

  # Application instances require outbound access through
  # the private application subnet NAT path.
  app_egress_cidr_ipv4 = "0.0.0.0/0"

  common_tags = local.common_tags
}


# ============================================================
# LocalStack Default Security Group
# ============================================================

data "aws_security_group" "localstack_default" {
  count = var.localstack_use_default_security_group ? 1 : 0

  vpc_id = module.network.vpc_id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}


# ============================================================
# Effective EC2 Security Groups
# ============================================================

locals {
  ec2_effective_security_group_ids = (
    var.localstack_use_default_security_group
    ? [data.aws_security_group.localstack_default[0].id]
    : [module.security.app_security_group_id]
  )
}