import os
import uuid

import boto3
import pytest
from botocore.exceptions import ClientError


LOCALSTACK_ENDPOINT = os.getenv(
    "LOCALSTACK_ENDPOINT",
    "http://localhost:4566",
)

AWS_REGION = os.getenv(
    "AWS_REGION",
    "ap-northeast-1",
)

PROJECT_NAME = os.getenv(
    "PROJECT_NAME",
    "aws-enterprise-lab",
)

ENVIRONMENT = os.getenv(
    "ENVIRONMENT",
    "localstack",
)

BUCKET_NAME = os.getenv(
    "S3_BUCKET_NAME",
    f"{PROJECT_NAME}-{ENVIRONMENT}-data",
)


@pytest.fixture(scope="session")
def s3():
    return boto3.client(
        "s3",
        endpoint_url=LOCALSTACK_ENDPOINT,
        region_name=AWS_REGION,
        aws_access_key_id=os.getenv(
            "AWS_ACCESS_KEY_ID",
            "test",
        ),
        aws_secret_access_key=os.getenv(
            "AWS_SECRET_ACCESS_KEY",
            "test",
        ),
        aws_session_token=os.getenv(
            "AWS_SESSION_TOKEN",
            "test",
        ),
    )


def test_bucket_exists(s3):
    response = s3.list_buckets()

    bucket_names = {
        bucket["Name"]
        for bucket in response.get("Buckets", [])
    }

    assert BUCKET_NAME in bucket_names


def test_bucket_region(s3):
    response = s3.get_bucket_location(
        Bucket=BUCKET_NAME
    )

    location = response.get(
        "LocationConstraint"
    )

    if AWS_REGION == "us-east-1":
        assert location in (
            None,
            "us-east-1",
        )
    else:
        assert location == AWS_REGION


def test_versioning_enabled(s3):
    response = s3.get_bucket_versioning(
        Bucket=BUCKET_NAME
    )

    assert response.get("Status") == "Enabled"


def test_encryption_aes256(s3):
    response = s3.get_bucket_encryption(
        Bucket=BUCKET_NAME
    )

    rules = response[
        "ServerSideEncryptionConfiguration"
    ]["Rules"]

    algorithm = rules[0][
        "ApplyServerSideEncryptionByDefault"
    ]["SSEAlgorithm"]

    assert algorithm == "AES256"


def test_public_access_block(s3):
    response = s3.get_public_access_block(
        Bucket=BUCKET_NAME
    )

    config = response[
        "PublicAccessBlockConfiguration"
    ]

    assert config["BlockPublicAcls"] is True
    assert config["IgnorePublicAcls"] is True
    assert config["BlockPublicPolicy"] is True
    assert config["RestrictPublicBuckets"] is True


def test_tags(s3):
    response = s3.get_bucket_tagging(
        Bucket=BUCKET_NAME
    )

    tags = {
        item["Key"]: item["Value"]
        for item in response.get(
            "TagSet",
            [],
        )
    }

    assert tags.get("Project") == PROJECT_NAME
    assert tags.get("Environment") == ENVIRONMENT
    assert tags.get("Service") == "s3"
    assert tags.get("Component") == "storage"
    assert tags.get("ManagedBy") == "terraform"


def test_object_crud(s3):
    key = f"pytest/{uuid.uuid4()}.txt"
    content = b"localstack-s3-pytest"

    put_response = s3.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=content,
    )

    assert (
        put_response[
            "ResponseMetadata"
        ]["HTTPStatusCode"]
        == 200
    )

    head_response = s3.head_object(
        Bucket=BUCKET_NAME,
        Key=key,
    )

    assert (
        head_response["ContentLength"]
        == len(content)
    )

    get_response = s3.get_object(
        Bucket=BUCKET_NAME,
        Key=key,
    )

    downloaded = get_response["Body"].read()

    assert downloaded == content

    versions_response = (
        s3.list_object_versions(
            Bucket=BUCKET_NAME,
            Prefix=key,
        )
    )

    versions = [
        version
        for version
        in versions_response.get(
            "Versions",
            [],
        )
        if version["Key"] == key
    ]

    assert len(versions) >= 1

    for version in versions:
        s3.delete_object(
            Bucket=BUCKET_NAME,
            Key=key,
            VersionId=version[
                "VersionId"
            ],
        )


def test_lifecycle_not_configured(s3):
    try:
        response = (
            s3.get_bucket_lifecycle_configuration(
                Bucket=BUCKET_NAME
            )
        )
    except ClientError as exc:
        code = exc.response[
            "Error"
        ]["Code"]

        assert code in {
            "NoSuchLifecycleConfiguration",
            "NoSuchLifecycle",
        }

        return

    assert not response.get("Rules", [])
