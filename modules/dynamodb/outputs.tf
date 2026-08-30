# ============================================================
# DynamoDB - Table
# ============================================================

output "table_id" {
  description = "DynamoDB table ID."
  value       = aws_dynamodb_table.this.id
}

output "table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "DynamoDB table ARN."
  value       = aws_dynamodb_table.this.arn
}


# ============================================================
# DynamoDB - Keys
# ============================================================

output "hash_key" {
  description = "DynamoDB partition key attribute name."
  value       = aws_dynamodb_table.this.hash_key
}

output "range_key" {
  description = "DynamoDB sort key attribute name."
  value       = aws_dynamodb_table.this.range_key
}


# ============================================================
# DynamoDB - Billing
# ============================================================

output "billing_mode" {
  description = "DynamoDB table billing mode."
  value       = aws_dynamodb_table.this.billing_mode
}


# ============================================================
# DynamoDB - Streams
# ============================================================

output "stream_enabled" {
  description = "Whether DynamoDB Streams is enabled."
  value       = aws_dynamodb_table.this.stream_enabled
}

output "stream_arn" {
  description = "DynamoDB stream ARN when streams are enabled."

  value = (
    var.stream_enabled
    ? aws_dynamodb_table.this.stream_arn
    : null
  )
}

output "stream_label" {
  description = "DynamoDB stream label when streams are enabled."

  value = (
    var.stream_enabled
    ? aws_dynamodb_table.this.stream_label
    : null
  )
}


# ============================================================
# DynamoDB - TTL
# ============================================================

output "ttl_enabled" {
  description = "Whether DynamoDB TTL is enabled."
  value       = var.ttl_enabled
}

output "ttl_attribute_name" {
  description = "DynamoDB TTL attribute name."

  value = (
    var.ttl_enabled
    ? var.ttl_attribute_name
    : null
  )
}


# ============================================================
# DynamoDB - Encryption
# ============================================================

output "server_side_encryption_enabled" {
  description = "Whether DynamoDB server-side encryption is enabled."
  value       = var.server_side_encryption_enabled
}

output "kms_key_arn" {
  description = "Customer-managed KMS key ARN used by DynamoDB."

  value = (
    var.server_side_encryption_enabled
    ? var.kms_key_arn
    : null
  )
}


# ============================================================
# DynamoDB - Point-in-Time Recovery
# ============================================================

output "point_in_time_recovery_enabled" {
  description = "Whether DynamoDB point-in-time recovery is enabled."
  value       = var.point_in_time_recovery_enabled
}


# ============================================================
# DynamoDB - Table Class
# ============================================================

output "table_class" {
  description = "DynamoDB table class."
  value       = aws_dynamodb_table.this.table_class
}