# ============================================================
# Launch Template
# ============================================================

output "launch_template_id" {
  description = "Launch Template ID."
  value       = aws_launch_template.this.id
}

output "launch_template_arn" {
  description = "Launch Template ARN."
  value       = aws_launch_template.this.arn
}

output "launch_template_name" {
  description = "Launch Template name."
  value       = aws_launch_template.this.name
}

output "launch_template_latest_version" {
  description = "Latest Launch Template version."
  value       = aws_launch_template.this.latest_version
}

output "launch_template_default_version" {
  description = "Default Launch Template version."
  value       = aws_launch_template.this.default_version
}

# ============================================================
# Auto Scaling Group
# ============================================================

output "autoscaling_group_id" {
  description = "Auto Scaling Group ID."
  value       = aws_autoscaling_group.this.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name."
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "Auto Scaling Group ARN."
  value       = aws_autoscaling_group.this.arn
}

output "autoscaling_group_min_size" {
  description = "Minimum ASG capacity."
  value       = aws_autoscaling_group.this.min_size
}

output "autoscaling_group_desired_capacity" {
  description = "Desired ASG capacity."
  value       = aws_autoscaling_group.this.desired_capacity
}

output "autoscaling_group_max_size" {
  description = "Maximum ASG capacity."
  value       = aws_autoscaling_group.this.max_size
}

output "autoscaling_group_health_check_type" {
  description = "ASG health check type."
  value       = aws_autoscaling_group.this.health_check_type
}

output "autoscaling_group_vpc_zone_identifier" {
  description = "Subnet IDs used by the ASG."
  value       = aws_autoscaling_group.this.vpc_zone_identifier
}

output "autoscaling_group_target_group_arns" {
  description = "Target Group ARNs attached to the ASG."
  value       = aws_autoscaling_group.this.target_group_arns
}