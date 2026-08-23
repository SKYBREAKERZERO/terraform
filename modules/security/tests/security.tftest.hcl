# ============================================================
# Mock AWS Provider
# ============================================================

mock_provider "aws" {}


# ============================================================
# Application Security Group Baseline
# ============================================================

run "application_security_group_baseline" {
  command = plan

  variables {
    project_name = "aws-enterprise-lab"
    environment  = "localstack"

    vpc_id = "vpc-0123456789abcdef0"

    common_tags = {
      Project     = "aws-enterprise-lab"
      Environment = "localstack"
      ManagedBy   = "terraform"
    }
  }


  # ==========================================================
  # Security Group
  # ==========================================================

  assert {
    condition = (
      aws_security_group.app.name ==
      "aws-enterprise-lab-localstack-app-sg"
    )

    error_message = "Application security group name is incorrect."
  }

  assert {
    condition = (
      aws_security_group.app.vpc_id ==
      "vpc-0123456789abcdef0"
    )

    error_message = "Application security group must be created in the expected VPC."
  }

  assert {
    condition = (
      aws_security_group.app.revoke_rules_on_delete == true
    )

    error_message = "Application security group must revoke rules on delete."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.app_ipv4.ip_protocol == "-1"
    )

    error_message = "Application egress rule must allow all protocols."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.app_ipv4.cidr_ipv4 ==
      "0.0.0.0/0"
    )

    error_message = "Application egress rule must use the expected IPv4 CIDR."
  }


  # ==========================================================
  # Tags
  # ==========================================================

  assert {
    condition = (
      aws_security_group.app.tags["Name"] ==
      "aws-enterprise-lab-localstack-app-sg"
    )

    error_message = "Application security group Name tag is incorrect."
  }

  assert {
    condition = (
      aws_security_group.app.tags["Tier"] ==
      "private-app"
    )

    error_message = "Application security group Tier tag must be private-app."
  }

  assert {
    condition = (
      aws_security_group.app.tags["Role"] ==
      "application"
    )

    error_message = "Application security group Role tag must be application."
  }

  assert {
    condition = (
      aws_security_group.app.tags["Component"] ==
      "security"
    )

    error_message = "Application security group Component tag must be security."
  }

  assert {
    condition = (
      aws_security_group.app.tags["Service"] ==
      "ec2"
    )

    error_message = "Application security group Service tag must be ec2."
  }
}


# ============================================================
# Custom Egress CIDR
# ============================================================

run "custom_application_egress_cidr" {
  command = plan

  variables {
    project_name = "aws-enterprise-lab"
    environment  = "dev"

    vpc_id = "vpc-0123456789abcdef0"

    app_egress_cidr_ipv4 = "10.0.0.0/8"
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.app_ipv4.cidr_ipv4 ==
      "10.0.0.0/8"
    )

    error_message = "Custom application egress CIDR was not applied."
  }

  assert {
    condition = (
      aws_security_group.app.name ==
      "aws-enterprise-lab-dev-app-sg"
    )

    error_message = "Environment-specific security group naming is incorrect."
  }
}