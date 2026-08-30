# ============================================================
# DynamoDB
# ============================================================

module "dynamodb" {
  count = (
    var.dynamodb_enabled
    ? 1
    : 0
  )

  source = "../../modules/dynamodb"


  # ==========================================================
  # General
  # ==========================================================

  project_name = var.project_name
  environment  = var.environment

  table_name = (
    var.dynamodb_table_name
  )


  # ==========================================================
  # Keys
  # ==========================================================

  hash_key = (
    var.dynamodb_hash_key
  )

  hash_key_type = (
    var.dynamodb_hash_key_type
  )

  range_key = (
    var.dynamodb_range_key
  )

  range_key_type = (
    var.dynamodb_range_key_type
  )


  # ==========================================================
  # Billing
  # ==========================================================

  billing_mode = (
    var.dynamodb_billing_mode
  )

  read_capacity = (
    var.dynamodb_read_capacity
  )

  write_capacity = (
    var.dynamodb_write_capacity
  )


  # ==========================================================
  # TTL
  # ==========================================================

  ttl_enabled = (
    var.dynamodb_ttl_enabled
  )

  ttl_attribute_name = (
    var.dynamodb_ttl_attribute_name
  )


  # ==========================================================
  # Point-in-Time Recovery
  # ==========================================================

  point_in_time_recovery_enabled = (
    var.dynamodb_point_in_time_recovery_enabled
  )


  # ==========================================================
  # Encryption
  # ==========================================================

  server_side_encryption_enabled = (
    var.dynamodb_server_side_encryption_enabled
  )

  kms_key_arn = (
    var.dynamodb_kms_key_arn
  )


  # ==========================================================
  # Streams
  # ==========================================================

  stream_enabled = (
    var.dynamodb_stream_enabled
  )

  stream_view_type = (
    var.dynamodb_stream_view_type
  )


  # ==========================================================
  # Protection
  # ==========================================================

  deletion_protection_enabled = (
    var.dynamodb_deletion_protection_enabled
  )


  # ==========================================================
  # Table Class
  # ==========================================================

  table_class = (
    var.dynamodb_table_class
  )


  # ==========================================================
  # Tags
  # ==========================================================

  common_tags = (
    var.common_tags
  )
}