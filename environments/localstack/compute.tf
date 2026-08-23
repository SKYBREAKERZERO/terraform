# ============================================================
# Compute
# ============================================================

module "ec2" {
  source = "../../modules/ec2"

  project_name = var.project_name
  environment  = var.environment

  ami_id        = var.ec2_ami_id
  instance_type = var.ec2_instance_type

  # Deploy application EC2 instances only into private app subnets.
  subnet_ids = module.network.private_app_subnet_ids

  security_group_ids   = var.ec2_security_group_ids
  iam_instance_profile = var.ec2_iam_instance_profile

  # Enterprise baseline
  associate_public_ip_address = false
  enable_detailed_monitoring  = var.ec2_enable_detailed_monitoring
  ebs_optimized               = var.ec2_ebs_optimized

  # Root EBS
  root_volume_size      = var.ec2_root_volume_size
  root_volume_type      = var.ec2_root_volume_type
  root_volume_encrypted = true
  kms_key_id            = var.ec2_kms_key_id
  delete_on_termination = var.ec2_delete_on_termination

  # IMDSv2
  metadata_http_tokens = "required"
  metadata_hop_limit   = var.ec2_metadata_hop_limit

  # Bootstrap
  user_data = var.ec2_user_data

  # Tags
  common_tags = local.common_tags
}