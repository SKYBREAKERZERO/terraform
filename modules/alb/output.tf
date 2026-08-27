output "load_balancer_id" {
  description = "ALB ID."
  value       = aws_lb.this.id
}

output "load_balancer_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "load_balancer_arn_suffix" {
  description = "ALB ARN suffix."
  value       = aws_lb.this.arn_suffix
}

output "load_balancer_name" {
  description = "ALB name."
  value       = aws_lb.this.name
}

output "load_balancer_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "load_balancer_zone_id" {
  description = "ALB hosted zone ID."
  value       = aws_lb.this.zone_id
}

output "target_group_id" {
  description = "Target group ID."
  value       = aws_lb_target_group.this.id
}

output "target_group_arn" {
  description = "Target group ARN."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix."
  value       = aws_lb_target_group.this.arn_suffix
}

output "target_group_name" {
  description = "Target group name."
  value       = aws_lb_target_group.this.name
}

output "listener_id" {
  description = "ALB listener ID."
  value       = aws_lb_listener.http.id
}

output "listener_arn" {
  description = "ALB listener ARN."
  value       = aws_lb_listener.http.arn
}

output "attached_target_ids" {
  description = "Map of targets attached to the target group."

  value = {
    for key, attachment in aws_lb_target_group_attachment.this :
    key => attachment.target_id
  }
}