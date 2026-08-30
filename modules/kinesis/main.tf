# ============================================================
# Kinesis - Locals
# ============================================================

locals {
  stream_name = (
    var.stream_name != null
    ? var.stream_name
    : "${var.project_name}-${var.environment}-stream"
  )
}


# ============================================================
# Kinesis Data Stream
# ============================================================

resource "aws_kinesis_stream" "this" {
  name = local.stream_name


  # ==========================================================
  # Stream Mode
  # ==========================================================

  stream_mode_details {
    stream_mode = var.stream_mode
  }


  # ==========================================================
  # Shards
  # ==========================================================

  shard_count = (
    var.stream_mode == "PROVISIONED"
    ? var.shard_count
    : null
  )


  # ==========================================================
  # Retention
  # ==========================================================

  retention_period = var.retention_period


  # ==========================================================
  # Encryption
  # ==========================================================

  encryption_type = var.encryption_type

  kms_key_id = (
    var.encryption_type == "KMS"
    ? var.kms_key_id
    : null
  )


  # ==========================================================
  # Shard-Level CloudWatch Metrics
  # ==========================================================

  shard_level_metrics = var.shard_level_metrics


  # ==========================================================
  # Tags
  # ==========================================================

  tags = merge(
    var.common_tags,
    {
      Name      = local.stream_name
      Component = "streaming"
      Service   = "kinesis"
    }
  )


  # ==========================================================
  # Validation
  # ==========================================================

  lifecycle {
    precondition {
      condition = (
        var.stream_mode != "PROVISIONED" ||
        var.shard_count >= 1
      )

      error_message = "shard_count must be at least 1 when stream_mode is PROVISIONED."
    }

    precondition {
      condition = (
        var.encryption_type != "KMS" ||
        (
          var.kms_key_id != null &&
          length(trimspace(var.kms_key_id)) > 0
        )
      )

      error_message = "kms_key_id must be provided when encryption_type is KMS."
    }

    precondition {
      condition = (
        var.retention_period >= 24 &&
        var.retention_period <= 8760
      )

      error_message = "retention_period must be between 24 and 8760 hours."
    }
  }
}