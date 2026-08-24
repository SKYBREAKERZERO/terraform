resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.common_tags,
    {
      Name      = var.bucket_name
      Component = "storage"
      Service   = "s3"
    }
  )
}


resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.encryption_algorithm

      kms_master_key_id = (
        var.encryption_algorithm == "aws:kms"
        ? var.kms_key_arn
        : null
      )
    }

    bucket_key_enabled = (
      var.encryption_algorithm == "aws:kms"
      ? var.bucket_key_enabled
      : false
    )
  }
}


resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  ignore_public_acls      = var.ignore_public_acls
  block_public_policy     = var.block_public_policy
  restrict_public_buckets = var.restrict_public_buckets
}


resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.lifecycle_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  depends_on = [
    aws_s3_bucket_versioning.this
  ]

  rule {
    id     = "default-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = var.transition_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}