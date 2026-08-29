locals {
  launch_template_name = substr(
    "${var.project_name}-${var.environment}-lt",
    0,
    120
  )

  autoscaling_group_name = substr(
    "${var.project_name}-${var.environment}-asg",
    0,
    240
  )
}

# ============================================================
# Launch Template
# ============================================================

resource "aws_launch_template" "this" {
  name_prefix = "${local.launch_template_name}-"

  image_id      = var.ami_id
  instance_type = var.instance_type

  ebs_optimized = var.ebs_optimized

  vpc_security_group_ids = var.security_group_ids

  dynamic "iam_instance_profile" {
    for_each = (
      var.instance_profile_arn == null
      ? []
      : [1]
    )

    content {
      arn = var.instance_profile_arn
    }
  }

  user_data = (
    var.user_data == null
    ? null
    : base64encode(var.user_data)
  )

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  metadata_options {
    http_endpoint = var.metadata_http_endpoint
    http_tokens   = var.metadata_http_tokens

    http_put_response_hop_limit = (
      var.metadata_hop_limit
    )

    instance_metadata_tags = "disabled"
  }

  dynamic "block_device_mappings" {
    for_each = (
      var.manage_root_block_device
      ? [1]
      : []
    )

    content {
      device_name = var.root_device_name

      ebs {
        volume_size = var.root_volume_size
        volume_type = var.root_volume_type

        encrypted = var.root_volume_encrypted

        kms_key_id = (
          var.root_volume_encrypted
          ? var.root_kms_key_id
          : null
        )

        delete_on_termination = (
          var.root_delete_on_termination
        )
      }
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name      = "${var.project_name}-${var.environment}-app"
        Component = "compute"
        Service   = "ec2"
        ManagedBy = "asg"
        Tier      = "application"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.common_tags,
      {
        Name      = "${var.project_name}-${var.environment}-app-volume"
        Component = "compute"
        Service   = "ebs"
        ManagedBy = "asg"
        Tier      = "application"
      }
    )
  }

  tags = merge(
    var.common_tags,
    {
      Name      = local.launch_template_name
      Component = "compute"
      Service   = "launch-template"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================
# Auto Scaling Group
# ============================================================

resource "aws_autoscaling_group" "this" {
  name_prefix = "${local.autoscaling_group_name}-"

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  vpc_zone_identifier = var.subnet_ids

  target_group_arns = var.target_group_arns

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  default_instance_warmup = var.default_instance_warmup

  termination_policies = var.termination_policies

  protect_from_scale_in = var.protect_from_scale_in
  force_delete          = var.force_delete

  launch_template {
    id = aws_launch_template.this.id

    version = tostring(
      aws_launch_template.this.latest_version
    )
  }

  dynamic "instance_refresh" {
    for_each = (
      var.instance_refresh_enabled
      ? [1]
      : []
    )

    content {
      strategy = var.instance_refresh_strategy

      preferences {
        min_healthy_percentage = (
          var.instance_refresh_min_healthy_percentage
        )

        instance_warmup = (
          var.instance_refresh_instance_warmup
        )
      }
    }
  }

  dynamic "tag" {
    for_each = merge(
      var.common_tags,
      {
        Name      = "${var.project_name}-${var.environment}-app"
        Component = "compute"
        Service   = "autoscaling"
        ManagedBy = "asg"
        Tier      = "application"
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition = (
        var.min_size <= var.desired_capacity &&
        var.desired_capacity <= var.max_size
      )

      error_message = "ASG capacity must satisfy: min_size <= desired_capacity <= max_size."
    }
  }
}