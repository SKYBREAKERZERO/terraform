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
# Expected Configuration
# ============================================================

EXPECTED_HASH_KEY = os.getenv(
    "DYNAMODB_HASH_KEY",
    "id",
)

EXPECTED_HASH_KEY_TYPE = os.getenv(
    "DYNAMODB_HASH_KEY_TYPE",
    "S",
)

EXPECTED_RANGE_KEY = (
    os.getenv(
        "DYNAMODB_RANGE_KEY",
        "",
    )
    or None
)

EXPECTED_RANGE_KEY_TYPE = os.getenv(
    "DYNAMODB_RANGE_KEY_TYPE",
    "S",
)

EXPECTED_BILLING_MODE = os.getenv(
    "DYNAMODB_BILLING_MODE",
    "PAY_PER_REQUEST",
)

EXPECTED_READ_CAPACITY = int(
    os.getenv(
        "DYNAMODB_READ_CAPACITY",
        "5",
    )
)

EXPECTED_WRITE_CAPACITY = int(
    os.getenv(
        "DYNAMODB_WRITE_CAPACITY",
        "5",
    )
)

EXPECTED_TTL_ENABLED = (
    os.getenv(
        "DYNAMODB_TTL_ENABLED",
        "false",
    ).lower()
    == "true"
)

EXPECTED_TTL_ATTRIBUTE_NAME = os.getenv(
    "DYNAMODB_TTL_ATTRIBUTE_NAME",
    "expires_at",
)

EXPECTED_PITR_ENABLED = (
    os.getenv(
        "DYNAMODB_POINT_IN_TIME_RECOVERY_ENABLED",
        "false",
    ).lower()
    == "true"
)

EXPECTED_SSE_ENABLED = (
    os.getenv(
        "DYNAMODB_SERVER_SIDE_ENCRYPTION_ENABLED",
        "true",
    ).lower()
    == "true"
)

EXPECTED_KMS_KEY_ARN = (
    os.getenv(
        "DYNAMODB_KMS_KEY_ARN",
        "",
    )
    or None
)

EXPECTED_STREAM_ENABLED = (
    os.getenv(
        "DYNAMODB_STREAM_ENABLED",
        "false",
    ).lower()
    == "true"
)

EXPECTED_STREAM_VIEW_TYPE = os.getenv(
    "DYNAMODB_STREAM_VIEW_TYPE",
    "NEW_AND_OLD_IMAGES",
)

EXPECTED_DELETION_PROTECTION = (
    os.getenv(
        "DYNAMODB_DELETION_PROTECTION_ENABLED",
        "false",
    ).lower()
    == "true"
)

EXPECTED_TABLE_CLASS = os.getenv(
    "DYNAMODB_TABLE_CLASS",
    "STANDARD",
)

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_TABLE_NAME,
    "Component": "database",
    "Service": "dynamodb",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


# ============================================================
# Client
# ============================================================

dynamodb = boto3.client(
    "dynamodb",
    region_name=AWS_REGION,
    endpoint_url=LOCALSTACK_ENDPOINT,
)


# ============================================================
# Output Helpers
# ============================================================

def pass_check(
    message: str,
) -> None:
    global PASS_COUNT

    PASS_COUNT += 1

    print(
        f"[PASS] {message}"
    )


def warn_check(
    message: str,
) -> None:
    global WARN_COUNT

    WARN_COUNT += 1

    print(
        f"[WARN] {message}"
    )


def fail_check(
    message: str,
) -> None:
    global FAIL_COUNT

    FAIL_COUNT += 1

    print(
        f"[FAIL] {message}"
    )


def check_equal(
    label: str,
    actual: Any,
    expected: Any,
) -> None:
    if actual == expected:
        pass_check(
            f"{label}: {actual}"
        )

    else:
        fail_check(
            f"{label}: "
            f"expected={expected!r}, "
            f"actual={actual!r}"
        )


# ============================================================
# DynamoDB API Helpers
# ============================================================

def get_table() -> dict[str, Any]:
    response = dynamodb.describe_table(
        TableName=EXPECTED_TABLE_NAME,
    )

    return response.get(
        "Table",
        {},
    )


def get_ttl() -> dict[str, Any]:
    response = dynamodb.describe_time_to_live(
        TableName=EXPECTED_TABLE_NAME,
    )

    return response.get(
        "TimeToLiveDescription",
        {},
    )


def get_continuous_backups() -> dict[str, Any]:
    response = (
        dynamodb.describe_continuous_backups(
            TableName=EXPECTED_TABLE_NAME,
        )
    )

    return response.get(
        "ContinuousBackupsDescription",
        {},
    )


def get_tags(
    table_arn: str,
) -> dict[str, str]:
    response = dynamodb.list_tags_of_resource(
        ResourceArn=table_arn,
    )

    return {
        item.get("Key"): item.get("Value")
        for item in response.get(
            "Tags",
            [],
        )
        if item.get("Key")
    }


# ============================================================
# General Validation
# ============================================================

def validate_general(
    table: dict[str, Any],
) -> None:
    print()
    print("GENERAL")
    print("-" * 70)

    check_equal(
        "Table name",
        table.get("TableName"),
        EXPECTED_TABLE_NAME,
    )

    check_equal(
        "Table status",
        table.get("TableStatus"),
        "ACTIVE",
    )

    table_arn = table.get(
        "TableArn"
    )

    if table_arn:
        pass_check(
            f"Table ARN exists: {table_arn}"
        )

    else:
        fail_check(
            "Table ARN is missing."
        )

    table_id = table.get(
        "TableId"
    )

    if table_id:
        pass_check(
            f"Table ID exists: {table_id}"
        )

    else:
        warn_check(
            "Table ID was not returned."
        )


# ============================================================
# Key Schema Validation
# ============================================================

def validate_keys(
    table: dict[str, Any],
) -> None:
    print()
    print("KEY SCHEMA")
    print("-" * 70)

    key_schema = {
        item.get("KeyType"): item.get(
            "AttributeName"
        )
        for item in table.get(
            "KeySchema",
            [],
        )
    }

    attributes = {
        item.get("AttributeName"): item.get(
            "AttributeType"
        )
        for item in table.get(
            "AttributeDefinitions",
            [],
        )
    }

    check_equal(
        "Partition key",
        key_schema.get("HASH"),
        EXPECTED_HASH_KEY,
    )

    check_equal(
        "Partition key type",
        attributes.get(
            EXPECTED_HASH_KEY
        ),
        EXPECTED_HASH_KEY_TYPE,
    )

    if EXPECTED_RANGE_KEY is None:
        if "RANGE" not in key_schema:
            pass_check(
                "Sort key is not configured."
            )

        else:
            fail_check(
                "Unexpected sort key exists: "
                f"{key_schema.get('RANGE')}"
            )

    else:
        check_equal(
            "Sort key",
            key_schema.get("RANGE"),
            EXPECTED_RANGE_KEY,
        )

        check_equal(
            "Sort key type",
            attributes.get(
                EXPECTED_RANGE_KEY
            ),
            EXPECTED_RANGE_KEY_TYPE,
        )


# ============================================================
# Billing Validation
# ============================================================

def validate_billing(
    table: dict[str, Any],
) -> None:
    print()
    print("BILLING")
    print("-" * 70)

    billing_summary = table.get(
        "BillingModeSummary",
        {},
    )

    actual_billing_mode = (
        billing_summary.get(
            "BillingMode"
        )
        or "PROVISIONED"
    )

    check_equal(
        "Billing mode",
        actual_billing_mode,
        EXPECTED_BILLING_MODE,
    )

    if EXPECTED_BILLING_MODE == "PROVISIONED":
        throughput = table.get(
            "ProvisionedThroughput",
            {},
        )

        check_equal(
            "Read capacity",
            throughput.get(
                "ReadCapacityUnits"
            ),
            EXPECTED_READ_CAPACITY,
        )

        check_equal(
            "Write capacity",
            throughput.get(
                "WriteCapacityUnits"
            ),
            EXPECTED_WRITE_CAPACITY,
        )

    else:
        pass_check(
            "Provisioned capacity validation skipped "
            "for PAY_PER_REQUEST."
        )


# ============================================================
# TTL Validation
# ============================================================

def validate_ttl() -> None:
    print()
    print("TTL")
    print("-" * 70)

    try:
        ttl = get_ttl()

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "TTL API is unavailable or unsupported: "
            f"{error}"
        )
        return

    status = ttl.get(
        "TimeToLiveStatus"
    )

    if EXPECTED_TTL_ENABLED:
        if status in {
            "ENABLED",
            "ENABLING",
        }:
            pass_check(
                f"TTL status: {status}"
            )

        else:
            fail_check(
                "TTL should be enabled, "
                f"actual status={status!r}"
            )

        check_equal(
            "TTL attribute",
            ttl.get(
                "AttributeName"
            ),
            EXPECTED_TTL_ATTRIBUTE_NAME,
        )

    else:
        if status in {
            "DISABLED",
            "DISABLING",
            None,
        }:
            pass_check(
                f"TTL disabled: {status}"
            )

        else:
            fail_check(
                "TTL should be disabled, "
                f"actual status={status!r}"
            )


# ============================================================
# PITR Validation
# ============================================================

def validate_pitr() -> None:
    print()
    print("POINT-IN-TIME RECOVERY")
    print("-" * 70)

    try:
        backups = get_continuous_backups()

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "Continuous backups API is unavailable "
            f"or unsupported: {error}"
        )
        return

    recovery = backups.get(
        "PointInTimeRecoveryDescription",
        {},
    )

    status = recovery.get(
        "PointInTimeRecoveryStatus"
    )

    if EXPECTED_PITR_ENABLED:
        check_equal(
            "PITR status",
            status,
            "ENABLED",
        )

    else:
        if status in {
            "DISABLED",
            None,
        }:
            pass_check(
                f"PITR disabled: {status}"
            )

        else:
            fail_check(
                "PITR should be disabled, "
                f"actual status={status!r}"
            )


# ============================================================
# Encryption Validation
# ============================================================

def validate_encryption(
    table: dict[str, Any],
) -> None:
    print()
    print("SERVER-SIDE ENCRYPTION")
    print("-" * 70)

    sse = table.get(
        "SSEDescription",
        {},
    )

    if EXPECTED_SSE_ENABLED:
        if not sse:
            warn_check(
                "SSEDescription was not returned. "
                "LocalStack may omit SSE metadata."
            )

            return

        status = sse.get(
            "Status"
        )

        if status in {
            "ENABLED",
            "ENABLING",
        }:
            pass_check(
                f"SSE status: {status}"
            )

        else:
            fail_check(
                "SSE should be enabled, "
                f"actual status={status!r}"
            )

        if EXPECTED_KMS_KEY_ARN:
            check_equal(
                "KMS key ARN",
                sse.get(
                    "KMSMasterKeyArn"
                ),
                EXPECTED_KMS_KEY_ARN,
            )

        else:
            pass_check(
                "Customer-managed KMS key validation "
                "not required."
            )

    else:
        if not sse:
            pass_check(
                "SSE description is absent."
            )

        else:
            status = sse.get(
                "Status"
            )

            if status in {
                None,
                "DISABLED",
            }:
                pass_check(
                    f"SSE disabled: {status}"
                )

            else:
                warn_check(
                    "DynamoDB may still use default "
                    "service-side encryption even when "
                    "explicit SSE configuration is disabled."
                )


# ============================================================
# Stream Validation
# ============================================================

def validate_stream(
    table: dict[str, Any],
) -> None:
    print()
    print("DYNAMODB STREAM")
    print("-" * 70)

    stream = table.get(
        "StreamSpecification",
        {},
    )

    actual_enabled = stream.get(
        "StreamEnabled",
        False,
    )

    check_equal(
        "Stream enabled",
        actual_enabled,
        EXPECTED_STREAM_ENABLED,
    )

    if EXPECTED_STREAM_ENABLED:
        check_equal(
            "Stream view type",
            stream.get(
                "StreamViewType"
            ),
            EXPECTED_STREAM_VIEW_TYPE,
        )

        stream_arn = table.get(
            "LatestStreamArn"
        )

        if stream_arn:
            pass_check(
                f"Stream ARN exists: {stream_arn}"
            )

        else:
            fail_check(
                "Stream is enabled but LatestStreamArn "
                "is missing."
            )

    else:
        pass_check(
            "Stream view validation skipped."
        )


# ============================================================
# Deletion Protection Validation
# ============================================================

def validate_deletion_protection(
    table: dict[str, Any],
) -> None:
    print()
    print("DELETION PROTECTION")
    print("-" * 70)

    actual = table.get(
        "DeletionProtectionEnabled",
        False,
    )

    check_equal(
        "Deletion protection",
        actual,
        EXPECTED_DELETION_PROTECTION,
    )


# ============================================================
# Table Class Validation
# ============================================================

def validate_table_class(
    table: dict[str, Any],
) -> None:
    print()
    print("TABLE CLASS")
    print("-" * 70)

    summary = table.get(
        "TableClassSummary",
        {},
    )

    actual = summary.get(
        "TableClass"
    )

    if actual is None:
        actual = "STANDARD"

    check_equal(
        "Table class",
        actual,
        EXPECTED_TABLE_CLASS,
    )


# ============================================================
# Tag Validation
# ============================================================

def validate_tags(
    table: dict[str, Any],
) -> None:
    print()
    print("TAGS")
    print("-" * 70)

    table_arn = table.get(
        "TableArn"
    )

    if not table_arn:
        fail_check(
            "Cannot validate tags because "
            "TableArn is missing."
        )
        return

    try:
        tags = get_tags(
            table_arn
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "Tag API is unavailable or unsupported: "
            f"{error}"
        )
        return

    for key, expected_value in EXPECTED_TAGS.items():
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"Tag {key}: {actual_value}"
            )

        else:
            fail_check(
                f"Tag {key}: "
                f"expected={expected_value!r}, "
                f"actual={actual_value!r}"
            )


# ============================================================
# Index Validation
# ============================================================

def validate_indexes(
    table: dict[str, Any],
) -> None:
    print()
    print("INDEXES")
    print("-" * 70)

    global_indexes = table.get(
        "GlobalSecondaryIndexes",
        [],
    )

    local_indexes = table.get(
        "LocalSecondaryIndexes",
        [],
    )

    if not global_indexes:
        pass_check(
            "No global secondary indexes configured."
        )

    else:
        warn_check(
            "Global secondary indexes exist, "
            f"count={len(global_indexes)}."
        )

    if not local_indexes:
        pass_check(
            "No local secondary indexes configured."
        )

    else:
        warn_check(
            "Local secondary indexes exist, "
            f"count={len(local_indexes)}."
        )


# ============================================================
# Main
# ============================================================

def main() -> int:
    print(
        "=" * 70
    )

    print(
        "DYNAMODB VALIDATION"
    )

    print(
        "=" * 70
    )

    print()
    print(
        f"Endpoint:     {LOCALSTACK_ENDPOINT}"
    )
    print(
        f"Region:       {AWS_REGION}"
    )
    print(
        f"Project:      {PROJECT_NAME}"
    )
    print(
        f"Environment:  {ENVIRONMENT}"
    )
    print(
        f"Table:        {EXPECTED_TABLE_NAME}"
    )

    if not DYNAMODB_ENABLED:
        print()
        pass_check(
            "DynamoDB is disabled."
        )

        return 0

    try:
        table = get_table()

    except ClientError as error:
        error_info = error.response.get(
            "Error",
            {},
        )

        fail_check(
            "Unable to describe DynamoDB table: "
            f"{error_info.get('Code', 'Unknown')} - "
            f"{error_info.get('Message', str(error))}"
        )

        print_summary()

        return 1

    except BotoCoreError as error:
        fail_check(
            f"AWS SDK error: {error}"
        )

        print_summary()

        return 1

    except Exception as error:
        fail_check(
            "Unexpected error while retrieving table: "
            f"{type(error).__name__}: {error}"
        )

        print_summary()

        return 1

    validate_general(
        table
    )

    validate_keys(
        table
    )

    validate_billing(
        table
    )

    validate_ttl()

    validate_pitr()

    validate_encryption(
        table
    )

    validate_stream(
        table
    )

    validate_deletion_protection(
        table
    )

    validate_table_class(
        table
    )

    validate_indexes(
        table
    )

    validate_tags(
        table
    )

    print_summary()

    return (
        0
        if FAIL_COUNT == 0
        else 1
    )


# ============================================================
# Summary
# ============================================================

def print_summary() -> None:
    print()
    print(
        "=" * 70
    )

    print(
        "VALIDATION SUMMARY"
    )

    print(
        "=" * 70
    )

    print(
        f"PASS : {PASS_COUNT}"
    )

    print(
        f"WARN : {WARN_COUNT}"
    )

    print(
        f"FAIL : {FAIL_COUNT}"
    )

    print(
        "=" * 70
    )

    if FAIL_COUNT == 0:
        print(
            "[PASS] DynamoDB validation successful."
        )

    else:
        print(
            "[FAIL] DynamoDB validation failed."
        )


if __name__ == "__main__":
    sys.exit(
        main()
    )