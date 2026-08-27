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

variable "internal" {
  description = "Whether the Application Load Balancer is internal."
  type        = bool
  default     = false
}

variable "load_balancer_type" {
  description = "Type of load balancer."
  type        = string
  default     = "application"

  validation {
    condition     = var.load_balancer_type == "application"
    error_message = "This module currently supports only application load balancers."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs used by the ALB."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs are required for the ALB."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to the ALB."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group ID is required."
  }
}

variable "enable_deletion_protection" {
  description = "Whether deletion protection is enabled for the ALB."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
  default     = 60

  validation {
    condition = (
      var.idle_timeout >= 1 &&
      var.idle_timeout <= 4000
    )
    error_message = "idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "enable_http2" {
  description = "Whether HTTP/2 is enabled."
  type        = bool
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Whether cross-zone load balancing is enabled."
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Whether invalid HTTP header fields are dropped."
  type        = bool
  default     = true
}

variable "preserve_host_header" {
  description = "Whether the ALB preserves the Host header."
  type        = bool
  default     = false
}

variable "desync_mitigation_mode" {
  description = "HTTP desync mitigation mode."
  type        = string
  default     = "defensive"

  validation {
    condition = contains(
      [
        "monitor",
        "defensive",
        "strictest"
      ],
      var.desync_mitigation_mode
    )

    error_message = "desync_mitigation_mode must be monitor, defensive, or strictest."
  }
}

variable "target_port" {
  description = "Port used by the target group."
  type        = number
  default     = 80

  validation {
    condition = (
      var.target_port >= 1 &&
      var.target_port <= 65535
    )
    error_message = "target_port must be between 1 and 65535."
  }
}

variable "target_protocol" {
  description = "Protocol used by the target group."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
        "HTTPS"
      ],
      var.target_protocol
    )

    error_message = "target_protocol must be HTTP or HTTPS."
  }
}

variable "target_type" {
  description = "Target group target type."
  type        = string
  default     = "instance"

  validation {
    condition = contains(
      [
        "instance",
        "ip"
      ],
      var.target_type
    )

    error_message = "target_type must be instance or ip."
  }
}

variable "vpc_id" {
  description = "VPC ID for the target group."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id must not be empty."
  }
}

variable "target_ids" {
  description = "Map of logical target names to EC2 instance IDs or IP addresses."
  type        = map(string)
  default     = {}
}

variable "listener_port" {
  description = "Port used by the ALB listener."
  type        = number
  default     = 80

  validation {
    condition = (
      var.listener_port >= 1 &&
      var.listener_port <= 65535
    )
    error_message = "listener_port must be between 1 and 65535."
  }
}

variable "listener_protocol" {
  description = "Protocol used by the ALB listener."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
        "HTTPS"
      ],
      var.listener_protocol
    )

    error_message = "listener_protocol must be HTTP or HTTPS."
  }
}

variable "health_check_enabled" {
  description = "Whether target group health checks are enabled."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "HTTP health check path."
  type        = string
  default     = "/"
}

variable "health_check_protocol" {
  description = "Protocol used by health checks."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
        "HTTPS"
      ],
      var.health_check_protocol
    )

    error_message = "health_check_protocol must be HTTP or HTTPS."
  }
}

variable "health_check_port" {
  description = "Port used by health checks. Use traffic-port to use the target group's port."
  type        = string
  default     = "traffic-port"
}

variable "health_check_interval" {
  description = "Health check interval in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.health_check_interval >= 5 &&
      var.health_check_interval <= 300
    )
    error_message = "health_check_interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds."
  type        = number
  default     = 5

  validation {
    condition = (
      var.health_check_timeout >= 2 &&
      var.health_check_timeout <= 120
    )
    error_message = "health_check_timeout must be between 2 and 120 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks required."
  type        = number
  default     = 2

  validation {
    condition = (
      var.healthy_threshold >= 2 &&
      var.healthy_threshold <= 10
    )
    error_message = "healthy_threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks required."
  type        = number
  default     = 3

  validation {
    condition = (
      var.unhealthy_threshold >= 2 &&
      var.unhealthy_threshold <= 10
    )
    error_message = "unhealthy_threshold must be between 2 and 10."
  }
}

variable "health_check_matcher" {
  description = "HTTP status codes considered healthy."
  type        = string
  default     = "200-399"
}

variable "deregistration_delay" {
  description = "Time in seconds before a deregistered target stops receiving traffic."
  type        = number
  default     = 30

  validation {
    condition = (
      var.deregistration_delay >= 0 &&
      var.deregistration_delay <= 3600
    )
    error_message = "deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "slow_start" {
  description = "Slow start duration in seconds. Set to 0 to disable."
  type        = number
  default     = 0

  validation {
    condition = (
      var.slow_start == 0 ||
      (
        var.slow_start >= 30 &&
        var.slow_start <= 900
      )
    )
    error_message = "slow_start must be 0 or between 30 and 900 seconds."
  }
}

variable "common_tags" {
  description = "Common tags applied to ALB resources."
  type        = map(string)
  default     = {}
}