variable "project_name" {
    description = "Project name used for resource naming"
    type        = string

    validation {
        condition     = length(var.project_name) >= 3 && length(var.project_name) <= 30
        error_message = "project_name must be between 3 and 30 characters."
    }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["localstack", "dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: localstack, dev, stg, prod."
  }
}

variable "common_tags" {
  description = "Common tags applied to network resources"
  type        = map(string)
  default     = {}
}

variable "enable_dns_support" {
  description = "Whether DNS resolution is supported by the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether instances in the VPC receive DNS hostnames"
  type        = bool
  default     = true
}

variable "instance_tenancy" {
  description = "Default tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "instance_tenancy must be either default or dedicated."
  }
}

variable "enable_network_address_usage_metrics" {
  description = "Whether Network Address Usage metrics are enabled for the VPC"
  type        = bool
  default     = true
}

variable "public_subnets" {
  description = "Public subnet configuration"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "At least two public subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      can(cidrhost(subnet.cidr_block, 0))
    ])
    error_message = "All public subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      length(trimspace(subnet.availability_zone)) > 0
    ])
    error_message = "availability_zone must not be empty for public subnets."
  }
}

variable "map_public_ip_on_launch" {
  description = "Whether public IPv4 addresses are automatically assigned in public subnets"
  type        = bool
  default     = true
}


# ============================================================
# Private Application Subnets
# ============================================================

variable "private_app_subnets" {
  description = "Private application subnet configuration"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_app_subnets) >= 2
    error_message = "At least two private application subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_app_subnets) :
      can(cidrhost(subnet.cidr_block, 0))
    ])
    error_message = "All private application subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_app_subnets) :
      length(trimspace(subnet.availability_zone)) > 0
    ])
    error_message = "availability_zone must not be empty for private application subnets."
  }
}


# ============================================================
# Private Database Subnets
# ============================================================

variable "private_db_subnets" {
  description = "Private database subnet configuration"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_db_subnets) >= 2
    error_message = "At least two private database subnets must be configured."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_db_subnets) :
      can(cidrhost(subnet.cidr_block, 0))
    ])
    error_message = "All private database subnet CIDR blocks must be valid IPv4 CIDR blocks."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.private_db_subnets) :
      length(trimspace(subnet.availability_zone)) > 0
    ])
    error_message = "availability_zone must not be empty for private database subnets."
  }
}


# ============================================================
# Internet Gateway
# ============================================================

variable "create_internet_gateway" {
  description = "Whether to create an Internet Gateway for the VPC"
  type        = bool
  default     = true
}


# ============================================================
# NAT Gateway
# ============================================================

variable "nat_gateway_mode" {
  description = "NAT Gateway deployment mode"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single", "one-per-az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: none, single, one-per-az."
  }
}


# ============================================================
# VPC Gateway Endpoints
# ============================================================

variable "enable_s3_gateway_endpoint" {
  description = "Whether to create an S3 Gateway VPC Endpoint"
  type        = bool
  default     = true
}

variable "enable_dynamodb_gateway_endpoint" {
  description = "Whether to create a DynamoDB Gateway VPC Endpoint"
  type        = bool
  default     = false
}

variable "s3_endpoint_policy" {
  description = "Optional IAM policy JSON for the S3 Gateway VPC Endpoint"
  type        = string
  default     = null
}

variable "dynamodb_endpoint_policy" {
  description = "Optional IAM policy JSON for the DynamoDB Gateway VPC Endpoint"
  type        = string
  default     = null
}


# ============================================================
# VPC Interface Endpoints
# ============================================================

variable "interface_endpoint_services" {
  description = "Set of AWS service names for Interface VPC Endpoints"
  type        = set(string)
  default     = []
}

variable "interface_endpoint_private_dns_enabled" {
  description = "Whether private DNS is enabled for Interface VPC Endpoints"
  type        = bool
  default     = true
}

variable "interface_endpoint_security_group_ids" {
  description = "Security Group IDs associated with Interface VPC Endpoints"
  type        = list(string)
  default     = []
}


# ============================================================
# Network ACL
# ============================================================

variable "enable_network_acl" {
  description = "Whether custom Network ACLs are enabled"
  type        = bool
  default     = false
}

variable "public_nacl_rules" {
  description = "Network ACL rules applied to public subnets"
  type = list(object({
    rule_number = number
    egress      = bool
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.public_nacl_rules :
      contains(["allow", "deny"], rule.rule_action)
    ])
    error_message = "public_nacl_rules rule_action must be allow or deny."
  }
}

variable "private_app_nacl_rules" {
  description = "Network ACL rules applied to private application subnets"
  type = list(object({
    rule_number = number
    egress      = bool
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.private_app_nacl_rules :
      contains(["allow", "deny"], rule.rule_action)
    ])
    error_message = "private_app_nacl_rules rule_action must be allow or deny."
  }
}

variable "private_db_nacl_rules" {
  description = "Network ACL rules applied to private database subnets"
  type = list(object({
    rule_number = number
    egress      = bool
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = number
    to_port     = number
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.private_db_nacl_rules :
      contains(["allow", "deny"], rule.rule_action)
    ])
    error_message = "private_db_nacl_rules rule_action must be allow or deny."
  }
}


# ============================================================
# VPC Flow Logs
# ============================================================

variable "enable_flow_logs" {
  description = "Whether VPC Flow Logs are enabled"
  type        = bool
  default     = false
}

variable "flow_log_traffic_type" {
  description = "Traffic type captured by VPC Flow Logs"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "flow_log_destination_type" {
  description = "Destination type for VPC Flow Logs"
  type        = string
  default     = "cloud-watch-logs"

  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.flow_log_destination_type)
    error_message = "flow_log_destination_type must be cloud-watch-logs or s3."
  }
}

variable "flow_log_destination_arn" {
  description = "ARN of the destination for VPC Flow Logs"
  type        = string
  default     = null
}

variable "flow_log_iam_role_arn" {
  description = "IAM role ARN used by VPC Flow Logs when sending logs to CloudWatch Logs"
  type        = string
  default     = null
}

variable "flow_log_max_aggregation_interval" {
  description = "Maximum aggregation interval for VPC Flow Logs in seconds"
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "flow_log_max_aggregation_interval must be 60 or 600 seconds."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC"
  type        = string
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention period for VPC Flow Logs"
  type        = number
  default     = 30

  validation {
    condition = contains([
      1,
      3,
      5,
      7,
      14,
      30,
      60,
      90,
      120,
      150,
      180,
      365,
      400,
      545,
      731,
      1096,
      1827,
      2192,
      2557,
      2922,
      3288,
      3653
    ], var.flow_log_retention_days)

    error_message = "flow_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

# ============================================================
# Network ACL
# ============================================================

variable "enable_custom_network_acls" {
  description = "Whether to create custom Network ACLs"
  type        = bool
  default     = false
}

variable "public_nacl_ingress_rules" {
  description = "Ingress rules for the public Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}

variable "public_nacl_egress_rules" {
  description = "Egress rules for the public Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}

variable "private_app_nacl_ingress_rules" {
  description = "Ingress rules for the private application Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}

variable "private_app_nacl_egress_rules" {
  description = "Egress rules for the private application Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}

variable "private_db_nacl_ingress_rules" {
  description = "Ingress rules for the private database Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}

variable "private_db_nacl_egress_rules" {
  description = "Egress rules for the private database Network ACL"

  type = list(object({
    rule_number = number
    protocol    = string
    rule_action = string
    cidr_block  = string
    from_port   = optional(number)
    to_port     = optional(number)
  }))

  default = []
}