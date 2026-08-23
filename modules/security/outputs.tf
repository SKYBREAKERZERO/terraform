output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "app_security_group_arn" {
  description = "ARN of the application security group"
  value       = aws_security_group.app.arn
}

output "app_security_group_name" {
  description = "Name of the application security group"
  value       = aws_security_group.app.name
}