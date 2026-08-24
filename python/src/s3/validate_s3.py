import os
import sys

import boto3
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


class Result:
    def __init__(self):
        self.passed = 0
        self.warned = 0
        self.failed = 0

    def pass_(self, message):
        self.passed += 1
        print(f"[PASS] {message}")

    def warn(self, message):
        self.warned += 1
        print(f"[WARN] {message}")

    def fail(self, message):
        self.failed += 1
        print(f"[FAIL] {message}")


def get_s3_client():
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
    )


def validate_bucket_exists(
    s3,
    result,
):
    try:
        s3.head_bucket(
            Bucket=BUCKET_NAME
        )

        result.pass_(
            f"Bucket exists: {BUCKET_NAME}"
        )

    except ClientError as exc:
        result.fail(
            f"Bucket does not exist: {exc}"
        )


def validate_region(
    s3,
    result,
):
    try:
        response = s3.get_bucket_location(
            Bucket=BUCKET_NAME
        )

        location = response.get(
            "LocationConstraint"
        )

        if AWS_REGION == "us-east-1":
            if location in (
                None,
                "us-east-1",
            ):
                result.pass_(
                    "Bucket region is us-east-1"
                )
            else:
                result.fail(
                    f"Unexpected region: {location}"
                )

        elif location == AWS_REGION:
            result.pass_(
                f"Bucket region is {location}"
            )

        else:
            result.warn(
                f"Bucket region returned "
                f"{location}, expected "
                f"{AWS_REGION}"
            )

    except ClientError as exc:
        result.fail(
            f"Unable to read bucket region: "
            f"{exc}"
        )


def validate_versioning(
    s3,
    result,
):
    try:
        response = s3.get_bucket_versioning(
            Bucket=BUCKET_NAME
        )

        status = response.get("Status")

        if status == "Enabled":
            result.pass_(
                "Bucket versioning enabled"
            )
        else:
            result.fail(
                f"Versioning status: {status}"
            )

    except ClientError as exc:
        result.fail(
            f"Unable to read versioning: "
            f"{exc}"
        )


def validate_encryption(
    s3,
    result,
):
    try:
        response = s3.get_bucket_encryption(
            Bucket=BUCKET_NAME
        )

        rules = response[
            "ServerSideEncryptionConfiguration"
        ].get(
            "Rules",
            [],
        )

        if not rules:
            result.fail(
                "Encryption rules are empty"
            )
            return

        default_encryption = rules[0].get(
            "ApplyServerSideEncryptionByDefault",
            {},
        )

        algorithm = default_encryption.get(
            "SSEAlgorithm"
        )

        if algorithm in (
            "AES256",
            "aws:kms",
        ):
            result.pass_(
                "Encryption enabled: "
                f"{algorithm}"
            )
        else:
            result.fail(
                "Unexpected encryption "
                f"algorithm: {algorithm}"
            )

    except ClientError as exc:
        result.fail(
            f"Unable to read encryption: "
            f"{exc}"
        )


def validate_public_access(
    s3,
    result,
):
    try:
        response = (
            s3.get_public_access_block(
                Bucket=BUCKET_NAME
            )
        )

        config = response[
            "PublicAccessBlockConfiguration"
        ]

        checks = {
            "BlockPublicAcls":
                config.get(
                    "BlockPublicAcls"
                ),
            "IgnorePublicAcls":
                config.get(
                    "IgnorePublicAcls"
                ),
            "BlockPublicPolicy":
                config.get(
                    "BlockPublicPolicy"
                ),
            "RestrictPublicBuckets":
                config.get(
                    "RestrictPublicBuckets"
                ),
        }

        for name, enabled in checks.items():
            if enabled is True:
                result.pass_(
                    f"{name} enabled"
                )
            else:
                result.fail(
                    f"{name} disabled"
                )

    except ClientError as exc:
        result.fail(
            "Unable to read public access "
            f"block: {exc}"
        )


def validate_tags(
    s3,
    result,
):
    try:
        response = s3.get_bucket_tagging(
            Bucket=BUCKET_NAME
        )

        tags = {
            tag["Key"]: tag["Value"]
            for tag in response.get(
                "TagSet",
                [],
            )
        }

        expected = {
            "Project": PROJECT_NAME,
            "Environment": ENVIRONMENT,
            "Service": "s3",
            "Component": "storage",
        }

        for key, value in expected.items():
            actual = tags.get(key)

            if actual == value:
                result.pass_(
                    f"Tag {key}={value}"
                )
            else:
                result.fail(
                    f"Tag {key}: expected "
                    f"{value}, got {actual}"
                )

    except ClientError as exc:
        result.fail(
            f"Unable to read tags: {exc}"
        )


def main():
    print("=" * 60)
    print("S3 Validation")
    print("=" * 60)
    print(f"Endpoint : {LOCALSTACK_ENDPOINT}")
    print(f"Region   : {AWS_REGION}")
    print(f"Bucket   : {BUCKET_NAME}")
    print()

    s3 = get_s3_client()
    result = Result()

    validate_bucket_exists(
        s3,
        result,
    )

    validate_region(
        s3,
        result,
    )

    validate_versioning(
        s3,
        result,
    )

    validate_encryption(
        s3,
        result,
    )

    validate_public_access(
        s3,
        result,
    )

    validate_tags(
        s3,
        result,
    )

    print()
    print("=" * 60)
    print("S3 Validation Summary")
    print("=" * 60)
    print(f"PASS : {result.passed}")
    print(f"WARN : {result.warned}")
    print(f"FAIL : {result.failed}")
    print("=" * 60)

    if result.failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()