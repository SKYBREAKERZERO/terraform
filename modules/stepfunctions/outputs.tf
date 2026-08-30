# ============================================================
# Step Functions - Identity
# ============================================================

output "state_machine_id" {
  description = "Step Functions state machine ID."
  value       = aws_sfn_state_machine.this.id
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN."
  value       = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  description = "Step Functions state machine name."
  value       = aws_sfn_state_machine.this.name
}

output "state_machine_type" {
  description = "Step Functions state machine type."
  value       = aws_sfn_state_machine.this.type
}


# ============================================================
# Step Functions - IAM
# ============================================================

output "role_arn" {
  description = "IAM execution role ARN used by the state machine."
  value       = aws_sfn_state_machine.this.role_arn
}


# ============================================================
# Step Functions - Definition
# ============================================================

output "definition" {
  description = "Amazon States Language definition used by the state machine."
  value       = aws_sfn_state_machine.this.definition
}


# ============================================================
# Step Functions - Logging
# ============================================================

output "logging_enabled" {
  description = "Whether Step Functions logging is enabled."
  value       = var.logging_enabled
}

output "log_destination" {
  description = "CloudWatch Logs destination ARN configured for Step Functions."
  value       = var.log_destination
}

output "log_level" {
  description = "Step Functions logging level."
  value       = var.log_level
}

output "include_execution_data" {
  description = "Whether execution data is included in Step Functions logs."
  value       = var.include_execution_data
}


# ============================================================
# Step Functions - X-Ray
# ============================================================

output "tracing_enabled" {
  description = "Whether AWS X-Ray tracing is enabled."
  value       = var.tracing_enabled
}