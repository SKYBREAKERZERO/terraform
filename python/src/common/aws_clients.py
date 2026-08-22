import boto3

from common.config import Config


def get_aws_client(service_name: str):
    return boto3.client(
        service_name,
        region_name=Config.AWS_REGION,
        endpoint_url=Config.LOCALSTACK_ENDPOINT,
        aws_access_key_id=Config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=Config.AWS_SECRET_ACCESS_KEY,
    )


def get_ec2_client():
    return get_aws_client("ec2")