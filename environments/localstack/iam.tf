# ============================================================
# IAM
# ============================================================

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  # ==========================================================
  # EC2 Management
  # ==========================================================

  # Allow EC2 instances to be managed through AWS Systems Manager.
  enable_ssm = var.iam_enable_ssm

  # Allow CloudWatch Agent to publish metrics and logs.
  enable_cloudwatch_agent = var.iam_enable_cloudwatch_agent


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = local.common_tags
}