import os
import sys
from typing import Any

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


# ============================================================
# Environment
# ============================================================

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

DYNAMODB_ENABLED = (
    os.getenv(
        "DYNAMODB_ENABLED",
        "true",
    ).lower()
    == "true"
)

DYNAMODB_TABLE_NAME = os.getenv(
    "DYNAMODB_TABLE_NAME",
)

EXPECTED_TABLE_NAME = (
    DYNAMODB_TABLE_NAME
    if DYNAMODB_TABLE_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-table"
)


# ============================================================
# Client
# ============================================================

dynamodb = boto3.client(
    "dynamodb",
    region_name=AWS_REGION,
    endpoint_url=LOCALSTACK_ENDPOINT,
)


# ============================================================
# Helpers
# ============================================================

def print_section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def print_value(
    label: str,
    value: Any,
    indent: int = 0,
) -> None:
    prefix = " " * indent

    if value is None:
        value = "None"

    print(
        f"{prefix}{label:<28}: {value}"
    )


def bool_text(value: Any) -> str:
    return "true" if value else "false"


def get_table() -> dict[str, Any]:
    response = dynamodb.describe_table(
        TableName=EXPECTED_TABLE_NAME,
    )

    return response.get(
        "Table",
        {},
    )


def get_ttl() -> dict[str, Any]:
    try:
        response = dynamodb.describe_time_to_live(
            TableName=EXPECTED_TABLE_NAME,
        )

        return response.get(
            "TimeToLiveDescription",
            {},
        )

    except ClientError as error:
        print(
            "[WARN] Unable to retrieve TTL information:"
        )
        print(
            f"       {error}"
        )

        return {}


def get_pitr() -> dict[str, Any]:
    try:
        response = (
            dynamodb.describe_continuous_backups(
                TableName=EXPECTED_TABLE_NAME,
            )
        )

        return response.get(
            "ContinuousBackupsDescription",
            {},
        )

    except ClientError as error:
        print(
            "[WARN] Unable to retrieve PITR information:"
        )
        print(
            f"       {error}"
        )

        return {}


def get_tags(
    table_arn: str | None,
) -> list[dict[str, str]]:
    if not table_arn:
        return []

    try:
        response = dynamodb.list_tags_of_resource(
            ResourceArn=table_arn,
        )

        return response.get(
            "Tags",
            [],
        )

    except ClientError as error:
        print(
            "[WARN] Unable to retrieve DynamoDB tags:"
        )
        print(
            f"       {error}"
        )

        return []


# ============================================================
# Show Functions
# ============================================================

def show_general(
    table: dict[str, Any],
) -> None:
    print_section(
        "DYNAMODB TABLE"
    )

    print_value(
        "Table Name",
        table.get("TableName"),
    )

    print_value(
        "Table ARN",
        table.get("TableArn"),
    )

    print_value(
        "Table ID",
        table.get("TableId"),
    )

    print_value(
        "Status",
        table.get("TableStatus"),
    )

    print_value(
        "Creation Date",
        table.get("CreationDateTime"),
    )

    print_value(
        "Item Count",
        table.get("ItemCount"),
    )

    print_value(
        "Table Size Bytes",
        table.get("TableSizeBytes"),
    )

    print_value(
        "Table Class",
        table.get(
            "TableClassSummary",
            {},
        ).get(
            "TableClass",
            "STANDARD",
        ),
    )

    print_value(
        "Deletion Protection",
        bool_text(
            table.get(
                "DeletionProtectionEnabled",
                False,
            )
        ),
    )


def show_keys(
    table: dict[str, Any],
) -> None:
    print_section(
        "KEY SCHEMA"
    )

    key_schema = table.get(
        "KeySchema",
        [],
    )

    attributes = {
        item.get("AttributeName"): item.get(
            "AttributeType"
        )
        for item in table.get(
            "AttributeDefinitions",
            [],
        )
    }

    if not key_schema:
        print(
            "No key schema returned."
        )
        return

    for key in key_schema:
        name = key.get(
            "AttributeName"
        )

        key_type = key.get(
            "KeyType"
        )

        attribute_type = attributes.get(
            name
        )

        print()
        print_value(
            "Attribute",
            name,
            indent=2,
        )

        print_value(
            "Key Type",
            key_type,
            indent=2,
        )

        print_value(
            "Attribute Type",
            attribute_type,
            indent=2,
        )


def show_billing(
    table: dict[str, Any],
) -> None:
    print_section(
        "BILLING"
    )

    billing_summary = table.get(
        "BillingModeSummary",
        {},
    )

    billing_mode = billing_summary.get(
        "BillingMode"
    )

    if billing_mode is None:
        billing_mode = "PROVISIONED"

    print_value(
        "Billing Mode",
        billing_mode,
    )

    throughput = table.get(
        "ProvisionedThroughput",
        {},
    )

    print_value(
        "Read Capacity",
        throughput.get(
            "ReadCapacityUnits",
        ),
    )

    print_value(
        "Write Capacity",
        throughput.get(
            "WriteCapacityUnits",
        ),
    )

    print_value(
        "Read Count",
        throughput.get(
            "NumberOfDecreasesToday",
        ),
    )


def show_ttl(
    ttl: dict[str, Any],
) -> None:
    print_section(
        "TIME TO LIVE"
    )

    status = ttl.get(
        "TimeToLiveStatus",
        "UNKNOWN",
    )

    print_value(
        "TTL Status",
        status,
    )

    print_value(
        "TTL Attribute",
        ttl.get(
            "AttributeName"
        ),
    )


def show_pitr(
    pitr: dict[str, Any],
) -> None:
    print_section(
        "POINT-IN-TIME RECOVERY"
    )

    status = pitr.get(
        "ContinuousBackupsStatus",
        "UNKNOWN",
    )

    print_value(
        "Continuous Backups",
        status,
    )

    recovery = pitr.get(
        "PointInTimeRecoveryDescription",
        {},
    )

    print_value(
        "PITR Status",
        recovery.get(
            "PointInTimeRecoveryStatus",
        ),
    )

    print_value(
        "Earliest Restore Time",
        recovery.get(
            "EarliestRestorableDateTime",
        ),
    )

    print_value(
        "Latest Restore Time",
        recovery.get(
            "LatestRestorableDateTime",
        ),
    )


def show_encryption(
    table: dict[str, Any],
) -> None:
    print_section(
        "SERVER-SIDE ENCRYPTION"
    )

    sse = table.get(
        "SSEDescription",
        {},
    )

    if not sse:
        print_value(
            "SSE",
            "No SSEDescription returned",
        )
        return

    print_value(
        "Status",
        sse.get(
            "Status"
        ),
    )

    print_value(
        "SSE Type",
        sse.get(
            "SSEType"
        ),
    )

    print_value(
        "KMS Master Key ARN",
        sse.get(
            "KMSMasterKeyArn"
        ),
    )

    print_value(
        "Inaccessible Encryption Time",
        sse.get(
            "InaccessibleEncryptionDateTime"
        ),
    )


def show_stream(
    table: dict[str, Any],
) -> None:
    print_section(
        "DYNAMODB STREAM"
    )

    stream_specification = table.get(
        "StreamSpecification",
        {},
    )

    stream_enabled = stream_specification.get(
        "StreamEnabled",
        False,
    )

    print_value(
        "Stream Enabled",
        bool_text(
            stream_enabled
        ),
    )

    print_value(
        "Stream View Type",
        stream_specification.get(
            "StreamViewType"
        ),
    )

    print_value(
        "Latest Stream ARN",
        table.get(
            "LatestStreamArn"
        ),
    )

    print_value(
        "Latest Stream Label",
        table.get(
            "LatestStreamLabel"
        ),
    )


def show_indexes(
    table: dict[str, Any],
) -> None:
    print_section(
        "INDEXES"
    )

    global_indexes = table.get(
        "GlobalSecondaryIndexes",
        [],
    )

    local_indexes = table.get(
        "LocalSecondaryIndexes",
        [],
    )

    print_value(
        "Global Secondary Indexes",
        len(global_indexes),
    )

    for index in global_indexes:
        print()
        print_value(
            "GSI Name",
            index.get(
                "IndexName"
            ),
            indent=2,
        )

        print_value(
            "GSI Status",
            index.get(
                "IndexStatus"
            ),
            indent=2,
        )

        print_value(
            "GSI ARN",
            index.get(
                "IndexArn"
            ),
            indent=2,
        )

    print()

    print_value(
        "Local Secondary Indexes",
        len(local_indexes),
    )

    for index in local_indexes:
        print()
        print_value(
            "LSI Name",
            index.get(
                "IndexName"
            ),
            indent=2,
        )

        print_value(
            "LSI ARN",
            index.get(
                "IndexArn"
            ),
            indent=2,
        )


def show_tags(
    tags: list[dict[str, str]],
) -> None:
    print_section(
        "TAGS"
    )

    if not tags:
        print(
            "No tags returned."
        )
        return

    sorted_tags = sorted(
        tags,
        key=lambda item: item.get(
            "Key",
            "",
        ),
    )

    for tag in sorted_tags:
        print_value(
            tag.get(
                "Key",
                "Unknown",
            ),
            tag.get(
                "Value",
                "",
            ),
        )


# ============================================================
# Main
# ============================================================

def main() -> int:
    print(
        "=" * 70
    )

    print(
        "DYNAMODB INFORMATION"
    )

    print(
        "=" * 70
    )

    print()

    print_value(
        "Endpoint",
        LOCALSTACK_ENDPOINT,
    )

    print_value(
        "Region",
        AWS_REGION,
    )

    print_value(
        "Project",
        PROJECT_NAME,
    )

    print_value(
        "Environment",
        ENVIRONMENT,
    )

    print_value(
        "Expected Table",
        EXPECTED_TABLE_NAME,
    )

    if not DYNAMODB_ENABLED:
        print()
        print(
            "[INFO] DynamoDB is disabled."
        )

        return 0

    try:
        table = get_table()

        table_arn = table.get(
            "TableArn"
        )

        ttl = get_ttl()

        pitr = get_pitr()

        tags = get_tags(
            table_arn
        )

        show_general(
            table
        )

        show_keys(
            table
        )

        show_billing(
            table
        )

        show_ttl(
            ttl
        )

        show_pitr(
            pitr
        )

        show_encryption(
            table
        )

        show_stream(
            table
        )

        show_indexes(
            table
        )

        show_tags(
            tags
        )

    except ClientError as error:
        error_info = error.response.get(
            "Error",
            {},
        )

        error_code = error_info.get(
            "Code",
            "Unknown",
        )

        error_message = error_info.get(
            "Message",
            str(error),
        )

        print()
        print(
            "[ERROR] DynamoDB API request failed."
        )

        print_value(
            "Error Code",
            error_code,
        )

        print_value(
            "Message",
            error_message,
        )

        return 1

    except BotoCoreError as error:
        print()
        print(
            "[ERROR] AWS SDK error:"
        )

        print(
            f"        {error}"
        )

        return 1

    except Exception as error:
        print()
        print(
            "[ERROR] Unexpected error:"
        )

        print(
            f"        {type(error).__name__}: {error}"
        )

        return 1

    print()
    print(
        "=" * 70
    )

    print(
        "[PASS] DynamoDB information displayed successfully."
    )

    print(
        "=" * 70
    )

    return 0


if __name__ == "__main__":
    sys.exit(
        main()
    )