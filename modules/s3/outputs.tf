output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "versioning_status" {
  description = "Versioning status of the S3 bucket"
  value = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

output "encryption_algorithm" {
  description = "Server-side encryption algorithm configured for the bucket"
  value       = var.encryption_algorithm
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 encryption when SSE-KMS is enabled"
  value       = var.encryption_algorithm == "aws:kms" ? var.kms_key_arn : null
}

output "bucket_key_enabled" {
  description = "Whether S3 Bucket Key is effectively enabled"
  value = (
    var.encryption_algorithm == "aws:kms"
    ? var.bucket_key_enabled
    : false
  )
}

output "public_access_block_enabled" {
  description = "Whether all S3 public access protections are enabled"
  value = (
    var.block_public_acls &&
    var.ignore_public_acls &&
    var.block_public_policy &&
    var.restrict_public_buckets
  )
}

output "lifecycle_enabled" {
  description = "Whether lifecycle management is enabled"
  value       = var.lifecycle_enabled
}