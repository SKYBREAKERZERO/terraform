locals {
    name_prefix = "${var.project_name}-${var.environment}"

    common_tags = merge(
        var.common_tags,
        {
            Component = "identity"
            Service = "ec2"
        }
    )
}