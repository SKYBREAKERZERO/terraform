module "sns" {
  count = var.sns_enabled ? 1 : 0

  source = "../../modules/sns"

  project_name = var.project_name
  environment  = var.environment

  topic_name   = var.sns_topic_name
  display_name = var.sns_display_name

  kms_master_key_id = var.sns_kms_master_key_id

  fifo_topic = var.sns_fifo_topic

  content_based_deduplication = (
    var.sns_content_based_deduplication
  )

  subscriptions = var.sns_subscriptions

  common_tags = local.common_tags
}