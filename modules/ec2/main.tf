# ============================================================
# EC2 Application Instances
# ============================================================

resource "aws_instance" "this" {
  for_each = var.subnet_ids

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = each.value

  # ==========================================================
  # Network
  # ==========================================================

  vpc_security_group_ids = var.security_group_ids

  # Private application instances must not receive public IPs.
  associate_public_ip_address = var.associate_public_ip_address

  source_dest_check = true


  # ==========================================================
  # IAM
  # ==========================================================

  iam_instance_profile = var.iam_instance_profile


  # ==========================================================
  # Monitoring / Performance
  # ==========================================================

  monitoring    = var.enable_detailed_monitoring
  ebs_optimized = var.ebs_optimized


  # ==========================================================
  # User Data
  # ==========================================================

  user_data = var.user_data

  # Recreate instance when bootstrap configuration changes.
  user_data_replace_on_change = true


  # ==========================================================
  # Instance Metadata Service
  # ==========================================================

  metadata_options {
    http_endpoint = "enabled"

    # Enterprise baseline: IMDSv2
    http_tokens = var.metadata_http_tokens

    http_put_response_hop_limit = var.metadata_hop_limit

    instance_metadata_tags = "enabled"
  }


  # ==========================================================
  # Root EBS Volume
  # ==========================================================

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type

    encrypted  = var.root_volume_encrypted
    kms_key_id = var.kms_key_id

    delete_on_termination = var.delete_on_termination

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-${each.key}-root"
        Tier = "private-app"
        Role = "root-volume"
      }
    )
  }


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-${each.key}-ec2"

      Tier = "private-app"
      Role = "application"

      SubnetRole = each.key
    }
  )


  # ==========================================================
  # Enterprise Guardrails
  # ==========================================================

  lifecycle {

    # Private application instances must never receive
    # directly assigned public IP addresses.
    precondition {
      condition = (
        var.associate_public_ip_address == false
      )

      error_message = "Private application EC2 instances must not receive public IP addresses."
    }

    # Root volumes must remain encrypted.
    precondition {
      condition = (
        var.root_volume_encrypted == true
      )

      error_message = "EC2 root EBS volumes must be encrypted."
    }

    # Require IMDSv2.
    precondition {
      condition = (
        var.metadata_http_tokens == "required"
      )

      error_message = "EC2 instances must require IMDSv2 tokens."
    }
  }
}