# ============================================================
# ALB
# ============================================================

variable "alb_internal" {
  description = "Whether the ALB is internal."
  type        = bool
  default     = false
}

variable "alb_load_balancer_type" {
  description = "ALB type."
  type        = string
  default     = "application"

  validation {
    condition     = var.alb_load_balancer_type == "application"
    error_message = "alb_load_balancer_type must be application."
  }
}

# ============================================================
# ALB - Protection / Behavior
# ============================================================

variable "alb_enable_deletion_protection" {
  description = "Whether ALB deletion protection is enabled."
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
  default     = 60

  validation {
    condition = (
      var.alb_idle_timeout >= 1 &&
      var.alb_idle_timeout <= 4000
    )

    error_message = "alb_idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "alb_enable_http2" {
  description = "Whether HTTP/2 is enabled."
  type        = bool
  default     = true
}

variable "alb_enable_cross_zone_load_balancing" {
  description = "Whether cross-zone load balancing is enabled."
  type        = bool
  default     = true
}

variable "alb_drop_invalid_header_fields" {
  description = "Whether invalid HTTP header fields are dropped."
  type        = bool
  default     = true
}

variable "alb_preserve_host_header" {
  description = "Whether the original Host header is preserved."
  type        = bool
  default     = false
}

variable "alb_desync_mitigation_mode" {
  description = "ALB HTTP desync mitigation mode."
  type        = string
  default     = "defensive"

  validation {
    condition = contains(
      [
        "monitor",
        "defensive",
        "strictest"
      ],
      var.alb_desync_mitigation_mode
    )

    error_message = "alb_desync_mitigation_mode must be monitor, defensive, or strictest."
  }
}

# ============================================================
# ALB - Target Group
# ============================================================

variable "alb_target_port" {
  description = "Target group traffic port."
  type        = number
  default     = 80

  validation {
    condition = (
      var.alb_target_port >= 1 &&
      var.alb_target_port <= 65535
    )

    error_message = "alb_target_port must be between 1 and 65535."
  }
}

variable "alb_target_protocol" {
  description = "Target group traffic protocol."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
        "HTTPS"
      ],
      var.alb_target_protocol
    )

    error_message = "alb_target_protocol must be HTTP or HTTPS."
  }
}

variable "alb_target_type" {
  description = "Target group target type."
  type        = string
  default     = "instance"

  validation {
    condition = contains(
      [
        "instance",
        "ip"
      ],
      var.alb_target_type
    )

    error_message = "alb_target_type must be instance or ip."
  }
}

# ============================================================
# ALB - Listener
# ============================================================

variable "alb_listener_port" {
  description = "ALB listener port."
  type        = number
  default     = 80

  validation {
    condition = (
      var.alb_listener_port >= 1 &&
      var.alb_listener_port <= 65535
    )

    error_message = "alb_listener_port must be between 1 and 65535."
  }
}

variable "alb_listener_protocol" {
  description = "ALB listener protocol."
  type        = string
  default     = "HTTP"

  validation {
    condition     = var.alb_listener_protocol == "HTTP"
    error_message = "The current ALB implementation supports only HTTP listeners."
  }
}

# ============================================================
# ALB - Health Check
# ============================================================

variable "alb_health_check_enabled" {
  description = "Whether target group health checks are enabled."
  type        = bool
  default     = true
}

variable "alb_health_check_protocol" {
  description = "Target group health check protocol."
  type        = string
  default     = "HTTP"

  validation {
    condition = contains(
      [
        "HTTP",
        "HTTPS"
      ],
      var.alb_health_check_protocol
    )

    error_message = "alb_health_check_protocol must be HTTP or HTTPS."
  }
}

variable "alb_health_check_port" {
  description = "Target group health check port."
  type        = string
  default     = "traffic-port"

  validation {
    condition = (
      var.alb_health_check_port == "traffic-port" ||
      can(
        regex(
          "^[0-9]+$",
          var.alb_health_check_port
        )
      )
    )

    error_message = "alb_health_check_port must be traffic-port or a numeric port string."
  }
}

variable "alb_health_check_path" {
  description = "Target group HTTP health check path."
  type        = string
  default     = "/"

  validation {
    condition     = startswith(var.alb_health_check_path, "/")
    error_message = "alb_health_check_path must start with '/'."
  }
}

variable "alb_health_check_interval" {
  description = "Target group health check interval in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.alb_health_check_interval >= 5 &&
      var.alb_health_check_interval <= 300
    )

    error_message = "alb_health_check_interval must be between 5 and 300 seconds."
  }
}

variable "alb_health_check_timeout" {
  description = "Target group health check timeout in seconds."
  type        = number
  default     = 5

  validation {
    condition = (
      var.alb_health_check_timeout >= 2 &&
      var.alb_health_check_timeout <= 120
    )

    error_message = "alb_health_check_timeout must be between 2 and 120 seconds."
  }
}

variable "alb_healthy_threshold" {
  description = "Number of successful health checks required before a target becomes healthy."
  type        = number
  default     = 2

  validation {
    condition = (
      var.alb_healthy_threshold >= 2 &&
      var.alb_healthy_threshold <= 10
    )

    error_message = "alb_healthy_threshold must be between 2 and 10."
  }
}

variable "alb_unhealthy_threshold" {
  description = "Number of failed health checks required before a target becomes unhealthy."
  type        = number
  default     = 3

  validation {
    condition = (
      var.alb_unhealthy_threshold >= 2 &&
      var.alb_unhealthy_threshold <= 10
    )

    error_message = "alb_unhealthy_threshold must be between 2 and 10."
  }
}

variable "alb_health_check_matcher" {
  description = "HTTP response status code matcher used by the target group."
  type        = string
  default     = "200-399"

  validation {
    condition = can(
      regex(
        "^[0-9]{3}(-[0-9]{3})?$",
        var.alb_health_check_matcher
      )
    )

    error_message = "alb_health_check_matcher must be a status code or range such as 200 or 200-399."
  }
}

# ============================================================
# ALB - Target Lifecycle
# ============================================================

variable "alb_deregistration_delay" {
  description = "Target deregistration delay in seconds."
  type        = number
  default     = 30

  validation {
    condition = (
      var.alb_deregistration_delay >= 0 &&
      var.alb_deregistration_delay <= 3600
    )

    error_message = "alb_deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "alb_slow_start" {
  description = "Target slow start duration in seconds. Set to 0 to disable."
  type        = number
  default     = 0

  validation {
    condition = (
      var.alb_slow_start == 0 ||
      (
        var.alb_slow_start >= 30 &&
        var.alb_slow_start <= 900
      )
    )

    error_message = "alb_slow_start must be 0 or between 30 and 900 seconds."
  }
}