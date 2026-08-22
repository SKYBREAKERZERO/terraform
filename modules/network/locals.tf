locals {
  name_prefix = "${var.project_name}-${var.environment}"

  network_tags = merge(
    var.common_tags,
    {
      component = "network"
    }
  )
}