# ============================================================
# Lambda - Identity
# ============================================================

output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Lambda function invoke ARN."
  value       = aws_lambda_function.this.invoke_arn
}


# ============================================================
# Lambda - Version
# ============================================================

output "version" {
  description = "Published Lambda function version."
  value       = aws_lambda_function.this.version
}

output "qualified_arn" {
  description = "Qualified ARN for the published Lambda version."
  value       = aws_lambda_function.this.qualified_arn
}


# ============================================================
# Lambda - IAM
# ============================================================

output "role_arn" {
  description = "IAM execution role ARN used by the Lambda function."
  value       = aws_lambda_function.this.role
}


# ============================================================
# Lambda - Runtime
# ============================================================

output "runtime" {
  description = "Lambda runtime."
  value       = aws_lambda_function.this.runtime
}

output "handler" {
  description = "Lambda handler."
  value       = aws_lambda_function.this.handler
}

output "architectures" {
  description = "Lambda instruction set architectures."
  value       = aws_lambda_function.this.architectures
}


# ============================================================
# Lambda - Compute
# ============================================================

output "memory_size" {
  description = "Lambda memory size in MB."
  value       = aws_lambda_function.this.memory_size
}

output "timeout" {
  description = "Lambda timeout in seconds."
  value       = aws_lambda_function.this.timeout
}


# ============================================================
# Lambda - Source Code
# ============================================================

output "source_code_hash" {
  description = "Lambda deployment package source code hash."
  value       = aws_lambda_function.this.source_code_hash
}

output "source_code_size" {
  description = "Lambda deployment package size in bytes."
  value       = aws_lambda_function.this.source_code_size
}


# ============================================================
# Lambda - Metadata
# ============================================================

output "last_modified" {
  description = "Date and time the Lambda function was last modified."
  value       = aws_lambda_function.this.last_modified
}

output "signing_job_arn" {
  description = "ARN of the signing job associated with the Lambda function."
  value       = aws_lambda_function.this.signing_job_arn
}

output "signing_profile_version_arn" {
  description = "ARN of the signing profile version associated with the Lambda function."
  value       = aws_lambda_function.this.signing_profile_version_arn
}


# ============================================================
# Lambda - Configuration
# ============================================================

output "publish" {
  description = "Whether Lambda version publishing is enabled."
  value       = var.publish
}

output "reserved_concurrent_executions" {
  description = "Reserved concurrent executions configured for the Lambda function."
  value       = aws_lambda_function.this.reserved_concurrent_executions
}

output "tracing_mode" {
  description = "AWS X-Ray tracing mode."
  value       = var.tracing_mode
}