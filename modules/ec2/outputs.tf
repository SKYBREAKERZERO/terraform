# ============================================================
# EC2 Outputs
# ============================================================

output "instance_ids" {
  description = "Map of EC2 instance IDs"

  value = {
    for key, instance in aws_instance.this :
    key => instance.id
  }
}

output "instance_arns" {
  description = "Map of EC2 instance ARNs"

  value = {
    for key, instance in aws_instance.this :
    key => instance.arn
  }
}

output "private_ips" {
  description = "Map of EC2 private IP addresses"

  value = {
    for key, instance in aws_instance.this :
    key => instance.private_ip
  }
}

output "public_ips" {
  description = "Map of EC2 public IP addresses"

  value = {
    for key, instance in aws_instance.this :
    key => instance.public_ip
  }
}

output "availability_zones" {
  description = "Map of EC2 instance availability zones"

  value = {
    for key, instance in aws_instance.this :
    key => instance.availability_zone
  }
}

output "primary_network_interface_ids" {
  description = "Map of primary network interface IDs"

  value = {
    for key, instance in aws_instance.this :
    key => instance.primary_network_interface_id
  }
}

output "subnet_ids" {
  description = "Map of subnet IDs used by EC2 instances"

  value = {
    for key, instance in aws_instance.this :
    key => instance.subnet_id
  }
}

output "instance_states" {
  description = "Map of EC2 instance states for diagnostics"

  value = {
    for key, instance in aws_instance.this :
    key => instance.instance_state
  }
}