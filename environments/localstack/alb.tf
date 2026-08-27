module "alb1" {
  source = "../../modules/alb"

  project_name = var.project_name
  environment = var.environment

  internal = false
  load_balancer_type = "application"

  subnet_ids = values(
    module.vpc1.public_subnet_ids
  )

  security_group_ids = [
    module.security.alb_security_group_id
  ]

  enable_deletion_protection = false

  idle_timeout = 60
  enable_http2 = true

  enable_cross_zone_load_balancing = true

  drop_invalid_header_fields = true
  preserve_host_header = false
  desync_mitigation_mode = "defensive"

  vpc_id = module.network.vpc_id

  target_port     = 80
  target_protocol = "HTTP"
  target_type     = "instance"

  target_ids = module.ec2.instance_ids

  listener_port     = 80
  listener_protocol = "HTTP"

  health_check_enabled  = true
  health_check_path     = "/"
  health_check_protocol = "HTTP"
  health_check_port     = "traffic-port"

  health_check_interval = 30
  health_check_timeout  = 5

  healthy_threshold   = 2
  unhealthy_threshold = 3

  health_check_matcher = "200-399"

  deregistration_delay = 30
  slow_start           = 0

  common_tags = local.common_tags
}