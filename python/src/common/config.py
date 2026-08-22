import os


class Config:
    AWS_REGION = os.getenv(
        "AWS_REGION",
        "ap-northeast-1",
    )

    LOCALSTACK_ENDPOINT = os.getenv(
        "LOCALSTACK_ENDPOINT",
        "http://localhost:4566",
    )

    AWS_ACCESS_KEY_ID = os.getenv(
        "AWS_ACCESS_KEY_ID",
        "test",
    )

    AWS_SECRET_ACCESS_KEY = os.getenv(
        "AWS_SECRET_ACCESS_KEY",
        "test",
    )

    PROJECT_NAME = os.getenv(
        "PROJECT_NAME",
        "aws-enterprise-lab",
    )

    ENVIRONMENT = os.getenv(
        "ENVIRONMENT",
        "localstack",
    )