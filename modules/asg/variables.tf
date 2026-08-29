# ============================================================
# General
# ============================================================

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name must not be empty."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}

# ============================================================
# Launch Template - Compute
# ============================================================

variable "ami_id" {
  description = "AMI ID used by the Launch Template."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9A-Za-z]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type used by the Launch Template."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type must not be empty."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to instances."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group ID is required."
  }
}

variable "instance_profile_arn" {
  description = "IAM instance profile ARN attached to EC2 instances."
  type        = string
  default     = null
  nullable    = true
}

variable "user_data" {
  description = "Optional user data script. Plain text is accepted and encoded by the module."
  type        = string
  default     = null
  nullable    = true
}

# ============================================================
# Launch Template - EBS
# ============================================================

variable "manage_root_block_device" {
  description = "Whether the Launch Template explicitly manages the root EBS volume."
  type        = bool
  default     = true
}

variable "root_device_name" {
  description = "Root device name used by the AMI."
  type        = string
  default     = "/dev/xvda"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "root_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"

  validation {
    condition = contains(
      [
        "gp2",
        "gp3",
        "io1",
        "io2"
      ],
      var.root_volume_type
    )

    error_message = "root_volume_type must be gp2, gp3, io1, or io2."
  }
}

variable "root_volume_encrypted" {
  description = "Whether the root EBS volume is encrypted."
  type        = bool
  default     = true
}

variable "root_kms_key_id" {
  description = "Optional KMS key ID or ARN used for root EBS encryption."
  type        = string
  default     = null
  nullable    = true
}

variable "root_delete_on_termination" {
  description = "Whether the root EBS volume is deleted when the instance terminates."
  type        = bool
  default     = true
}

# ============================================================
# Launch Template - Metadata / Monitoring
# ============================================================

variable "metadata_http_endpoint" {
  description = "Whether IMDS endpoint is enabled."
  type        = string
  default     = "enabled"

  validation {
    condition = contains(
      [
        "enabled",
        "disabled"
      ],
      var.metadata_http_endpoint
    )

    error_message = "metadata_http_endpoint must be enabled or disabled."
  }
}

variable "metadata_http_tokens" {
  description = "Whether IMDSv2 tokens are required."
  type        = string
  default     = "required"

  validation {
    condition = contains(
      [
        "optional",
        "required"
      ],
      var.metadata_http_tokens
    )

    error_message = "metadata_http_tokens must be optional or required."
  }
}

variable "metadata_hop_limit" {
  description = "IMDS response hop limit."
  type        = number
  default     = 1

  validation {
    condition = (
      var.metadata_hop_limit >= 1 &&
      var.metadata_hop_limit <= 64
    )

    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}

variable "enable_detailed_monitoring" {
  description = "Whether detailed EC2 monitoring is enabled."
  type        = bool
  default     = false
}

variable "ebs_optimized" {
  description = "Whether EBS optimization is enabled."
  type        = bool
  default     = false
}

# ============================================================
# Auto Scaling Group - Network
# ============================================================

variable "subnet_ids" {
  description = "Private subnet IDs used by the Auto Scaling Group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs are required for the ASG."
  }
}

variable "target_group_arns" {
  description = "Target Group ARNs attached to the Auto Scaling Group."
  type        = list(string)
  default     = []
}

# ============================================================
# Auto Scaling Group - Capacity
# ============================================================

variable "min_size" {
  description = "Minimum number of EC2 instances."
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be zero or greater."
  }
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= 0
    error_message = "desired_capacity must be zero or greater."
  }
}

variable "max_size" {
  description = "Maximum number of EC2 instances."
  type        = number
  default     = 10

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be at least 1."
  }
}

# ============================================================
# Auto Scaling Group - Health
# ============================================================

variable "health_check_type" {
  description = "Health check type used by the ASG."
  type        = string
  default     = "EC2"

  validation {
    condition = contains(
      [
        "EC2",
        "ELB"
      ],
      var.health_check_type
    )

    error_message = "health_check_type must be EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  description = "Grace period before ASG health checks begin."
  type        = number
  default     = 300

  validation {
    condition     = var.health_check_grace_period >= 0
    error_message = "health_check_grace_period must be zero or greater."
  }
}

# ============================================================
# Auto Scaling Group - Lifecycle
# ============================================================

variable "default_instance_warmup" {
  description = "Default instance warmup time in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.default_instance_warmup >= 0
    error_message = "default_instance_warmup must be zero or greater."
  }
}

variable "termination_policies" {
  description = "Termination policies used by the ASG."
  type        = list(string)
  default     = ["Default"]
}

variable "protect_from_scale_in" {
  description = "Whether new instances are protected from scale-in."
  type        = bool
  default     = false
}

variable "force_delete" {
  description = "Whether the ASG can be forcibly deleted."
  type        = bool
  default     = false
}

# ============================================================
# Instance Refresh
# ============================================================

variable "instance_refresh_enabled" {
  description = "Whether ASG Instance Refresh is enabled."
  type        = bool
  default     = true
}

variable "instance_refresh_strategy" {
  description = "Instance Refresh strategy."
  type        = string
  default     = "Rolling"

  validation {
    condition     = var.instance_refresh_strategy == "Rolling"
    error_message = "Only Rolling instance refresh is currently supported."
  }
}

variable "instance_refresh_min_healthy_percentage" {
  description = "Minimum percentage of healthy instances during Instance Refresh."
  type        = number
  default     = 50

  validation {
    condition = (
      var.instance_refresh_min_healthy_percentage >= 0 &&
      var.instance_refresh_min_healthy_percentage <= 100
    )

    error_message = "instance_refresh_min_healthy_percentage must be between 0 and 100."
  }
}

variable "instance_refresh_instance_warmup" {
  description = "Warmup time for instances during Instance Refresh."
  type        = number
  default     = 300

  validation {
    condition     = var.instance_refresh_instance_warmup >= 0
    error_message = "instance_refresh_instance_warmup must be zero or greater."
  }
}

# ============================================================
# Tags
# ============================================================

variable "common_tags" {
  description = "Common tags applied to ASG and Launch Template resources."
  type        = map(string)
  default     = {}
}