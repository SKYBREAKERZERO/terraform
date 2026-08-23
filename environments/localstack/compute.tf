# ============================================================
# Compute
# ============================================================

module "ec2" {
  source = "../../modules/ec2"

  project_name = var.project_name
  environment  = var.environment

  ami_id        = var.ec2_ami_id
  instance_type = var.ec2_instance_type


  # ==========================================================
  # Network
  # ==========================================================

  # Deploy application EC2 instances only into private
  # application subnets.
  subnet_ids = module.network.private_app_subnet_ids

  # LocalStack compatibility:
  # - true  -> VPC default security group
  # - false -> enterprise application security group
  #
  # The actual selection logic is defined in security.tf.
  security_group_ids = local.ec2_effective_security_group_ids


  # ==========================================================
  # IAM
  # ==========================================================

  # Attach the IAM instance profile used for SSM and
  # CloudWatch Agent permissions.
  iam_instance_profile = module.iam.ec2_instance_profile_name


  # ==========================================================
  # Network Security Baseline
  # ==========================================================

  # Application instances must remain private.
  associate_public_ip_address = false


  # ==========================================================
  # Monitoring / Performance
  # ==========================================================

  enable_detailed_monitoring = var.ec2_enable_detailed_monitoring
  ebs_optimized              = var.ec2_ebs_optimized


  # ==========================================================
  # Root EBS
  # ==========================================================

  root_volume_size      = var.ec2_root_volume_size
  root_volume_type      = var.ec2_root_volume_type
  root_volume_encrypted = true
  kms_key_id            = var.ec2_kms_key_id
  delete_on_termination = var.ec2_delete_on_termination


  # ==========================================================
  # IMDSv2
  # ==========================================================

  metadata_http_tokens = "required"
  metadata_hop_limit   = var.ec2_metadata_hop_limit


  # ==========================================================
  # Bootstrap
  # ==========================================================

  user_data = var.ec2_user_data


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = local.common_tags
}