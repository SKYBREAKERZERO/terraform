module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment

  bucket_name = "${var.project_name}-${var.environment}-data"

  force_destroy      = true
  versioning_enabled = true

  encryption_algorithm = "AES256"
  bucket_key_enabled   = false

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

  lifecycle_enabled = false

  transition_days                    = 30
  expiration_days                    = 365
  noncurrent_version_expiration_days = 90

  common_tags = local.common_tags
}