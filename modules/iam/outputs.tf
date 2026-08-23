output "ec2_role_name" {
    description = "Name of the EC2 IAM role"
    value = aws_iam_role.ec2.name
}

output "ec2_role_arn" {
    description = "ARN of the EC2 IAM role"
    value = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "ssm_policy_arn" {
  description = "ARN of the SSM policy when enabled"
  value       = var.enable_ssm ? aws_iam_policy.ssm[0].arn : null
}

output "cloudwatch_agent_policy_arn" {
  description = "ARN of the CloudWatch Agent policy when enabled"
  value       = var.enable_cloudwatch_agent ? aws_iam_policy.cloudwatch_agent[0].arn : null
}