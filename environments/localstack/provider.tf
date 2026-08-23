provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  s3_use_path_style = true

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2            = var.localstack_endpoint
    s3             = var.localstack_endpoint
    sqs            = var.localstack_endpoint
    sns            = var.localstack_endpoint
    dynamodb       = var.localstack_endpoint
    lambda         = var.localstack_endpoint
    events         = var.localstack_endpoint

    iam = var.localstack_endpoint
    sts = var.localstack_endpoint
    kms = var.localstack_endpoint

    cloudwatch     = var.localstack_endpoint
    cloudwatchlogs = var.localstack_endpoint

    secretsmanager = var.localstack_endpoint
    ssm            = var.localstack_endpoint
  }

  default_tags {
    tags = local.common_tags
  }
}