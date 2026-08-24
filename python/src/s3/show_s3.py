import json
import os

import boto3


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


def print_json(title, value):
    print()
    print("=" * 60)
    print(title)
    print("=" * 60)
    print(
        json.dumps(
            value,
            indent=2,
            default=str,
        )
    )


def main():
    s3 = get_s3_client()

    buckets = s3.list_buckets()

    print_json(
        "S3 Buckets",
        buckets.get("Buckets", []),
    )

    print()
    print(f"Target bucket: {BUCKET_NAME}")

    try:
        location = s3.get_bucket_location(
            Bucket=BUCKET_NAME
        )

        print_json(
            "Bucket Location",
            location,
        )
    except Exception as exc:
        print(f"[ERROR] Bucket location: {exc}")

    try:
        versioning = s3.get_bucket_versioning(
            Bucket=BUCKET_NAME
        )

        print_json(
            "Versioning",
            versioning,
        )
    except Exception as exc:
        print(f"[ERROR] Versioning: {exc}")

    try:
        encryption = s3.get_bucket_encryption(
            Bucket=BUCKET_NAME
        )

        print_json(
            "Encryption",
            encryption,
        )
    except Exception as exc:
        print(f"[ERROR] Encryption: {exc}")

    try:
        public_access = (
            s3.get_public_access_block(
                Bucket=BUCKET_NAME
            )
        )

        print_json(
            "Public Access Block",
            public_access,
        )
    except Exception as exc:
        print(
            f"[ERROR] Public access block: {exc}"
        )

    try:
        tags = s3.get_bucket_tagging(
            Bucket=BUCKET_NAME
        )

        print_json(
            "Bucket Tags",
            tags,
        )
    except Exception as exc:
        print(f"[ERROR] Tags: {exc}")

    try:
        lifecycle = (
            s3.get_bucket_lifecycle_configuration(
                Bucket=BUCKET_NAME
            )
        )

        print_json(
            "Lifecycle",
            lifecycle,
        )
    except Exception:
        print()
        print("Lifecycle: not configured")

    try:
        objects = s3.list_objects_v2(
            Bucket=BUCKET_NAME
        )

        print_json(
            "Objects",
            objects.get("Contents", []),
        )
    except Exception as exc:
        print(f"[ERROR] Objects: {exc}")


if __name__ == "__main__":
    main()