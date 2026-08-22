import boto3

from common.config import Config


def get_aws_client(service_name: str):
    return boto3.client(
        service_name,
        region_name=Config.AWS_REGION,
        endpoint_url=Config.LOCALSTACK_ENDPOINT,
    )


def get_ec2_client():
    return get_aws_client("ec2")


def get_s3_client():
    return get_aws_client("s3")


def get_sqs_client():
    return get_aws_client("sqs")