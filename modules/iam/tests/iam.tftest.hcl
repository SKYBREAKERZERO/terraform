# ============================================================
# Mock AWS Provider
# ============================================================
mock_provider "aws" {}

override_data {
  target          = data.aws_iam_policy_document.ec2_assume_role
  override_during = plan

  values = {
    json = <<-JSON
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "EC2AssumeRole",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
              "Service": "ec2.amazonaws.com"
            }
          }
        ]
      }
    JSON
  }
}


override_data {
  target          = data.aws_iam_policy_document.ssm
  override_during = plan

  values = {
    json = <<-JSON
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "SSMInstanceManagement",
            "Effect": "Allow",
            "Action": [
              "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
          }
        ]
      }
    JSON
  }
}


override_data {
  target          = data.aws_iam_policy_document.cloudwatch_agent
  override_during = plan

  values = {
    json = <<-JSON
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "CloudWatchMetrics",
            "Effect": "Allow",
            "Action": [
              "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
          }
        ]
      }
    JSON
  }
}


# ============================================================
# IAM Baseline
# ============================================================

run "ec2_iam_baseline" {
  command = plan

  variables {
    project_name = "aws-enterprise-lab"
    environment  = "localstack"

    enable_ssm              = true
    enable_cloudwatch_agent = true

    common_tags = {
      Project     = "aws-enterprise-lab"
      Environment = "localstack"
      ManagedBy   = "terraform"
    }
  }


  # ==========================================================
  # EC2 IAM Role
  # ==========================================================

  assert {
    condition = (
      aws_iam_role.ec2.name ==
      "aws-enterprise-lab-localstack-ec2-role"
    )

    error_message = "EC2 IAM role name is incorrect."
  }

  assert {
    condition = (
      aws_iam_role.ec2.description ==
      "IAM role for private application EC2 instances"
    )

    error_message = "EC2 IAM role description is incorrect."
  }

  assert {
    condition = (
      aws_iam_role.ec2.tags["Name"] ==
      "aws-enterprise-lab-localstack-ec2-role"
    )

    error_message = "EC2 IAM role Name tag is incorrect."
  }

  assert {
    condition = (
      aws_iam_role.ec2.tags["Role"] ==
      "application"
    )

    error_message = "EC2 IAM role Role tag must be application."
  }

  assert {
    condition = (
      aws_iam_role.ec2.tags["Component"] ==
      "identity"
    )

    error_message = "EC2 IAM role Component tag must be identity."
  }

  assert {
    condition = (
      aws_iam_role.ec2.tags["Service"] ==
      "ec2"
    )

    error_message = "EC2 IAM role Service tag must be ec2."
  }


  # ==========================================================
  # EC2 Instance Profile
  # ==========================================================

  assert {
    condition = (
      aws_iam_instance_profile.ec2.name ==
      "aws-enterprise-lab-localstack-ec2-instance-profile"
    )

    error_message = "EC2 instance profile name is incorrect."
  }

  assert {
    condition = (
      aws_iam_instance_profile.ec2.role ==
      aws_iam_role.ec2.name
    )

    error_message = "EC2 instance profile must reference the EC2 IAM role."
  }

  assert {
    condition = (
      aws_iam_instance_profile.ec2.tags["Name"] ==
      "aws-enterprise-lab-localstack-ec2-instance-profile"
    )

    error_message = "EC2 instance profile Name tag is incorrect."
  }


  # ==========================================================
  # SSM Policy
  # ==========================================================

  assert {
    condition = (
      length(aws_iam_policy.ssm) == 1
    )

    error_message = "Exactly one SSM policy must be created when enable_ssm=true."
  }

  assert {
    condition = (
      aws_iam_policy.ssm[0].name ==
      "aws-enterprise-lab-localstack-ssm-core"
    )

    error_message = "SSM policy name is incorrect."
  }

  assert {
    condition = (
      length(aws_iam_role_policy_attachment.ssm) == 1
    )

    error_message = "SSM policy must be attached when enable_ssm=true."
  }

  assert {
    condition = (
      aws_iam_role_policy_attachment.ssm[0].role ==
      aws_iam_role.ec2.name
    )

    error_message = "SSM policy must be attached to the EC2 IAM role."
  }


  # ==========================================================
  # CloudWatch Agent Policy
  # ==========================================================

  assert {
    condition = (
      length(aws_iam_policy.cloudwatch_agent) == 1
    )

    error_message = "Exactly one CloudWatch Agent policy must be created when enable_cloudwatch_agent=true."
  }

  assert {
    condition = (
      aws_iam_policy.cloudwatch_agent[0].name ==
      "aws-enterprise-lab-localstack-cloudwatch-agent"
    )

    error_message = "CloudWatch Agent policy name is incorrect."
  }

  assert {
    condition = (
      length(aws_iam_role_policy_attachment.cloudwatch_agent) == 1
    )

    error_message = "CloudWatch Agent policy must be attached when enable_cloudwatch_agent=true."
  }

  assert {
    condition = (
      aws_iam_role_policy_attachment.cloudwatch_agent[0].role ==
      aws_iam_role.ec2.name
    )

    error_message = "CloudWatch Agent policy must be attached to the EC2 IAM role."
  }
}


# ============================================================
# Optional Policies Disabled
# ============================================================

run "optional_policies_disabled" {
  command = plan

  variables {
    project_name = "aws-enterprise-lab"
    environment  = "dev"

    enable_ssm              = false
    enable_cloudwatch_agent = false
  }


  # ==========================================================
  # Role / Instance Profile Still Exist
  # ==========================================================

  assert {
    condition = (
      aws_iam_role.ec2.name ==
      "aws-enterprise-lab-dev-ec2-role"
    )

    error_message = "EC2 IAM role must still be created when optional policies are disabled."
  }

  assert {
    condition = (
      aws_iam_instance_profile.ec2.name ==
      "aws-enterprise-lab-dev-ec2-instance-profile"
    )

    error_message = "EC2 instance profile must still be created when optional policies are disabled."
  }


  # ==========================================================
  # SSM Disabled
  # ==========================================================

  assert {
    condition = (
      length(aws_iam_policy.ssm) == 0
    )

    error_message = "SSM policy must not be created when enable_ssm=false."
  }

  assert {
    condition = (
      length(aws_iam_role_policy_attachment.ssm) == 0
    )

    error_message = "SSM policy attachment must not exist when enable_ssm=false."
  }


  # ==========================================================
  # CloudWatch Agent Disabled
  # ==========================================================

  assert {
    condition = (
      length(aws_iam_policy.cloudwatch_agent) == 0
    )

    error_message = "CloudWatch Agent policy must not be created when enable_cloudwatch_agent=false."
  }

  assert {
    condition = (
      length(aws_iam_role_policy_attachment.cloudwatch_agent) == 0
    )

    error_message = "CloudWatch Agent policy attachment must not exist when enable_cloudwatch_agent=false."
  }


  # ==========================================================
  # Outputs
  # ==========================================================

  assert {
    condition = (
      output.ssm_policy_arn == null
    )

    error_message = "ssm_policy_arn output must be null when SSM is disabled."
  }

  assert {
    condition = (
      output.cloudwatch_agent_policy_arn == null
    )

    error_message = "cloudwatch_agent_policy_arn output must be null when CloudWatch Agent is disabled."
  }
}