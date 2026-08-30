# ============================================================
# Kinesis - Stream
# ============================================================

output "stream_id" {
  description = "Kinesis stream ID."
  value       = aws_kinesis_stream.this.id
}

output "stream_name" {
  description = "Kinesis stream name."
  value       = aws_kinesis_stream.this.name
}

output "stream_arn" {
  description = "Kinesis stream ARN."
  value       = aws_kinesis_stream.this.arn
}

# ============================================================
# Kinesis - Stream Mode
# ============================================================

output "stream_mode" {
  description = "Kinesis stream capacity mode."
  value       = var.stream_mode
}

# ============================================================
# Kinesis - Shards
# ============================================================

output "shard_count" {
  description = "Configured shard count for PROVISIONED mode."

  value = (
    var.stream_mode == "PROVISIONED"
    ? var.shard_count
    : null
  )
}

# ============================================================
# Kinesis - Retention
# ============================================================

output "retention_period" {
  description = "Kinesis stream retention period in hours."
  value       = aws_kinesis_stream.this.retention_period
}

# ============================================================
# Kinesis - Encryption
# ============================================================

output "encryption_type" {
  description = "Kinesis stream server-side encryption type."
  value       = var.encryption_type
}

output "kms_key_id" {
  description = "KMS key ID or ARN used by the Kinesis stream."

  value = (
    var.encryption_type == "KMS"
    ? var.kms_key_id
    : null
  )
}

# ============================================================
# Kinesis - Metrics
# ============================================================

output "shard_level_metrics" {
  description = "Shard-level CloudWatch metrics enabled for the stream."
  value       = var.shard_level_metrics
}