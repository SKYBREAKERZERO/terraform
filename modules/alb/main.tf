locals {
  alb_name = substr(
    "${var.project_name}-${var.environment}-alb",
    0,
    32
  )

  target_group_name = substr(
    "${var.project_name}-${var.environment}-app-tg",
    0,
    32
  )
}

resource "aws_lb" "this" {
  name = local.alb_name

  internal           = var.internal
  load_balancer_type = var.load_balancer_type

  security_groups = var.security_group_ids
  subnets         = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  idle_timeout = var.idle_timeout

  enable_http2 = var.enable_http2

  enable_cross_zone_load_balancing = (
    var.enable_cross_zone_load_balancing
  )

  drop_invalid_header_fields = var.drop_invalid_header_fields
  preserve_host_header       = var.preserve_host_header
  desync_mitigation_mode     = var.desync_mitigation_mode

  tags = merge(
    var.common_tags,
    {
      Name      = local.alb_name
      Component = "load-balancer"
      Service   = "alb"
      Tier      = "public"
    }
  )
}

resource "aws_lb_target_group" "this" {
  name = local.target_group_name

  port        = var.target_port
  protocol    = var.target_protocol
  target_type = var.target_type
  vpc_id      = var.vpc_id

  deregistration_delay = var.deregistration_delay
  slow_start           = var.slow_start

  health_check {
    enabled = var.health_check_enabled

    protocol = var.health_check_protocol
    port     = var.health_check_port
    path     = var.health_check_path

    interval = var.health_check_interval
    timeout  = var.health_check_timeout

    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold

    matcher = var.health_check_matcher
  }

  tags = merge(
    var.common_tags,
    {
      Name      = local.target_group_name
      Component = "load-balancer"
      Service   = "target-group"
      Tier      = "application"
    }
  )
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = var.target_ids

  target_group_arn = aws_lb_target_group.this.arn

  target_id = each.value
  port      = var.target_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn

  port     = var.listener_port
  protocol = var.listener_protocol

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.project_name}-${var.environment}-listener"
      Component = "load-balancer"
      Service   = "listener"
    }
  )
}