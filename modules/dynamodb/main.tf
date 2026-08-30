# ============================================================
# DynamoDB - Locals
# ============================================================

locals {
  table_name = (
    var.table_name != null
    ? var.table_name
    : "${var.project_name}-${var.environment}-table"
  )
}


# ============================================================
# DynamoDB Table
# ============================================================

resource "aws_dynamodb_table" "this" {
  name = local.table_name

  billing_mode = var.billing_mode

  read_capacity = (
    var.billing_mode == "PROVISIONED"
    ? var.read_capacity
    : null
  )

  write_capacity = (
    var.billing_mode == "PROVISIONED"
    ? var.write_capacity
    : null
  )


  # ==========================================================
  # Keys
  # ==========================================================

  hash_key = var.hash_key

  range_key = (
    var.range_key
  )


  # ==========================================================
  # Attributes
  # ==========================================================

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = (
      var.range_key != null
      ? [1]
      : []
    )

    content {
      name = var.range_key
      type = var.range_key_type
    }
  }


  # ==========================================================
  # TTL
  # ==========================================================

  ttl {
    enabled = var.ttl_enabled

    attribute_name = (
      var.ttl_attribute_name
    )
  }


  # ==========================================================
  # Point-in-Time Recovery
  # ==========================================================

  point_in_time_recovery {
    enabled = (
      var.point_in_time_recovery_enabled
    )
  }


  # ==========================================================
  # Server-Side Encryption
  # ==========================================================

  server_side_encryption {
    enabled = (
      var.server_side_encryption_enabled
    )

    kms_key_arn = (
      var.server_side_encryption_enabled
      ? var.kms_key_arn
      : null
    )
  }


  # ==========================================================
  # DynamoDB Streams
  # ==========================================================

  stream_enabled = (
    var.stream_enabled
  )

  stream_view_type = (
    var.stream_enabled
    ? var.stream_view_type
    : null
  )


  # ==========================================================
  # Deletion Protection
  # ==========================================================

  deletion_protection_enabled = (
    var.deletion_protection_enabled
  )


  # ==========================================================
  # Table Class
  # ==========================================================

  table_class = (
    var.table_class
  )


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = local.table_name
      Component = "database"
      Service   = "dynamodb"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        var.range_key == null ||
        var.range_key != var.hash_key
      )

      error_message = "range_key must be different from hash_key."
    }

    precondition {
      condition = (
        var.billing_mode != "PROVISIONED" ||
        (
          var.read_capacity >= 1 &&
          var.write_capacity >= 1
        )
      )

      error_message = "read_capacity and write_capacity must be positive when billing_mode is PROVISIONED."
    }

    precondition {
      condition = (
        !var.server_side_encryption_enabled ||
        var.kms_key_arn == null ||
        length(trimspace(var.kms_key_arn)) > 0
      )

      error_message = "kms_key_arn must be null or non-empty when server-side encryption is enabled."
    }
  }
}