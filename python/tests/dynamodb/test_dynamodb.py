import json
import os
import time
from decimal import Decimal
from typing import Any

import boto3
import pytest
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

EXPECTED_TABLE_CLASS = os.getenv(
    "DYNAMODB_TABLE_CLASS",
    "STANDARD",
)

EXPECTED_DELETION_PROTECTION = (
    os.getenv(
        "DYNAMODB_DELETION_PROTECTION_ENABLED",
        "false",
    ).lower()
    == "true"
)


# ============================================================
# Runtime Test Item
# ============================================================

DEFAULT_TEST_ITEM = {
    EXPECTED_HASH_KEY: "pytest-dynamodb-item-001",
    "source": "pytest",
    "status": "smoke-test",
}

RAW_TEST_ITEM = os.getenv(
    "DYNAMODB_TEST_ITEM_JSON",
)

if RAW_TEST_ITEM:
    TEST_ITEM = json.loads(
        RAW_TEST_ITEM
    )
else:
    TEST_ITEM = DEFAULT_TEST_ITEM


# ============================================================
# Skip
# ============================================================

pytestmark = pytest.mark.skipif(
    not DYNAMODB_ENABLED,
    reason="DynamoDB is disabled.",
)


# ============================================================
# Clients
# ============================================================

@pytest.fixture(scope="session")
def dynamodb_client():
    return boto3.client(
        "dynamodb",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


@pytest.fixture(scope="session")
def dynamodb_resource():
    return boto3.resource(
        "dynamodb",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# Table Fixture
# ============================================================

@pytest.fixture(scope="session")
def table_description(
    dynamodb_client,
) -> dict[str, Any]:
    response = dynamodb_client.describe_table(
        TableName=EXPECTED_TABLE_NAME,
    )

    return response["Table"]


@pytest.fixture(scope="session")
def table(
    dynamodb_resource,
):
    return dynamodb_resource.Table(
        EXPECTED_TABLE_NAME
    )


# ============================================================
# Helpers
# ============================================================

def get_key_schema(
    table_description: dict[str, Any],
) -> dict[str, str]:
    return {
        item["KeyType"]: item["AttributeName"]
        for item in table_description.get(
            "KeySchema",
            [],
        )
    }


def get_attribute_definitions(
    table_description: dict[str, Any],
) -> dict[str, str]:
    return {
        item["AttributeName"]: item["AttributeType"]
        for item in table_description.get(
            "AttributeDefinitions",
            [],
        )
    }


def build_runtime_key() -> dict[str, Any]:
    key: dict[str, Any] = {
        EXPECTED_HASH_KEY: TEST_ITEM[
            EXPECTED_HASH_KEY
        ]
    }

    if EXPECTED_RANGE_KEY:
        if EXPECTED_RANGE_KEY not in TEST_ITEM:
            raise AssertionError(
                "DYNAMODB_TEST_ITEM_JSON must contain "
                f"the configured range key: "
                f"{EXPECTED_RANGE_KEY}"
            )

        key[
            EXPECTED_RANGE_KEY
        ] = TEST_ITEM[
            EXPECTED_RANGE_KEY
        ]

    return key


def normalize_value(
    value: Any,
) -> Any:
    if isinstance(
        value,
        Decimal,
    ):
        if value % 1 == 0:
            return int(value)

        return float(value)

    if isinstance(
        value,
        dict,
    ):
        return {
            key: normalize_value(item)
            for key, item in value.items()
        }

    if isinstance(
        value,
        list,
    ):
        return [
            normalize_value(item)
            for item in value
        ]

    return value


# ============================================================
# API / Table Tests
# ============================================================

def test_dynamodb_api_available(
    dynamodb_client,
):
    response = dynamodb_client.list_tables(
        Limit=1,
    )

    status_code = response[
        "ResponseMetadata"
    ][
        "HTTPStatusCode"
    ]

    assert status_code == 200


def test_table_exists(
    table_description,
):
    assert (
        table_description["TableName"]
        == EXPECTED_TABLE_NAME
    )


def test_table_is_active(
    table_description,
):
    assert (
        table_description["TableStatus"]
        == "ACTIVE"
    )


def test_table_arn_exists(
    table_description,
):
    table_arn = table_description.get(
        "TableArn"
    )

    assert table_arn
    assert EXPECTED_TABLE_NAME in table_arn


# ============================================================
# Key Schema Tests
# ============================================================

def test_partition_key(
    table_description,
):
    schema = get_key_schema(
        table_description
    )

    assert schema.get(
        "HASH"
    ) == EXPECTED_HASH_KEY


def test_partition_key_type(
    table_description,
):
    attributes = get_attribute_definitions(
        table_description
    )

    assert attributes.get(
        EXPECTED_HASH_KEY
    ) == EXPECTED_HASH_KEY_TYPE


def test_sort_key(
    table_description,
):
    schema = get_key_schema(
        table_description
    )

    actual = schema.get(
        "RANGE"
    )

    assert actual == EXPECTED_RANGE_KEY


def test_sort_key_type(
    table_description,
):
    if EXPECTED_RANGE_KEY is None:
        pytest.skip(
            "No sort key configured."
        )

    attributes = get_attribute_definitions(
        table_description
    )

    assert attributes.get(
        EXPECTED_RANGE_KEY
    ) == EXPECTED_RANGE_KEY_TYPE


# ============================================================
# Billing Tests
# ============================================================

def test_billing_mode(
    table_description,
):
    billing_summary = table_description.get(
        "BillingModeSummary",
        {},
    )

    actual = (
        billing_summary.get(
            "BillingMode"
        )
        or "PROVISIONED"
    )

    assert actual == EXPECTED_BILLING_MODE


# ============================================================
# TTL Tests
# ============================================================

def test_ttl_configuration(
    dynamodb_client,
):
    try:
        response = (
            dynamodb_client.describe_time_to_live(
                TableName=EXPECTED_TABLE_NAME,
            )
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        pytest.skip(
            "TTL API unavailable in LocalStack: "
            f"{error}"
        )

    ttl = response.get(
        "TimeToLiveDescription",
        {},
    )

    status = ttl.get(
        "TimeToLiveStatus"
    )

    if EXPECTED_TTL_ENABLED:
        assert status in {
            "ENABLED",
            "ENABLING",
        }

        assert (
            ttl.get(
                "AttributeName"
            )
            == EXPECTED_TTL_ATTRIBUTE_NAME
        )

    else:
        assert status in {
            None,
            "DISABLED",
            "DISABLING",
        }


# ============================================================
# Stream Tests
# ============================================================

def test_stream_configuration(
    table_description,
):
    stream = table_description.get(
        "StreamSpecification",
        {},
    )

    actual_enabled = stream.get(
        "StreamEnabled",
        False,
    )

    assert (
        actual_enabled
        == EXPECTED_STREAM_ENABLED
    )

    if EXPECTED_STREAM_ENABLED:
        assert (
            stream.get(
                "StreamViewType"
            )
            == EXPECTED_STREAM_VIEW_TYPE
        )

        assert table_description.get(
            "LatestStreamArn"
        )


# ============================================================
# Table Class Test
# ============================================================

def test_table_class(
    table_description,
):
    summary = table_description.get(
        "TableClassSummary",
        {},
    )

    actual = summary.get(
        "TableClass"
    )

    if actual is None:
        actual = "STANDARD"

    assert actual == EXPECTED_TABLE_CLASS


# ============================================================
# Deletion Protection Test
# ============================================================

def test_deletion_protection(
    table_description,
):
    actual = table_description.get(
        "DeletionProtectionEnabled",
        False,
    )

    assert (
        actual
        == EXPECTED_DELETION_PROTECTION
    )


# ============================================================
# Runtime CRUD Fixture
# ============================================================

@pytest.fixture(scope="session")
def runtime_item(
    table,
):
    key = build_runtime_key()

    item = dict(
        TEST_ITEM
    )

    if EXPECTED_TTL_ENABLED:
        item.setdefault(
            EXPECTED_TTL_ATTRIBUTE_NAME,
            int(
                time.time()
            )
            + 3600,
        )

    # --------------------------------------------------------
    # Cleanup stale test item before test
    # --------------------------------------------------------

    table.delete_item(
        Key=key,
    )

    # --------------------------------------------------------
    # PutItem
    # --------------------------------------------------------

    response = table.put_item(
        Item=item,
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    yield {
        "key": key,
        "item": item,
    }

    # --------------------------------------------------------
    # Cleanup after tests
    # --------------------------------------------------------

    table.delete_item(
        Key=key,
    )


# ============================================================
# Runtime Put/Get Tests
# ============================================================

def test_put_and_get_item(
    table,
    runtime_item,
):
    response = table.get_item(
        Key=runtime_item["key"],
        ConsistentRead=True,
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    assert "Item" in response

    actual_item = normalize_value(
        response["Item"]
    )

    expected_item = normalize_value(
        runtime_item["item"]
    )

    for key, expected_value in (
        expected_item.items()
    ):
        assert (
            actual_item.get(
                key
            )
            == expected_value
        )


# ============================================================
# Runtime Conditional Write Test
# ============================================================

def test_conditional_put_rejects_duplicate(
    table,
    runtime_item,
):
    expression = (
        f"attribute_not_exists("
        f"{EXPECTED_HASH_KEY}"
        f")"
    )

    with pytest.raises(
        ClientError
    ) as error_info:
        table.put_item(
            Item=runtime_item[
                "item"
            ],
            ConditionExpression=expression,
        )

    error = error_info.value

    error_code = error.response.get(
        "Error",
        {},
    ).get(
        "Code"
    )

    assert error_code in {
        "ConditionalCheckFailedException",
        "ConditionalCheckFailed",
    }


# ============================================================
# Runtime UpdateItem Test
# ============================================================

def test_update_item(
    table,
    runtime_item,
):
    response = table.update_item(
        Key=runtime_item["key"],
        UpdateExpression=(
            "SET #status = :status"
        ),
        ExpressionAttributeNames={
            "#status": "status",
        },
        ExpressionAttributeValues={
            ":status": "updated",
        },
        ReturnValues="ALL_NEW",
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    attributes = normalize_value(
        response.get(
            "Attributes",
            {},
        )
    )

    assert (
        attributes.get(
            "status"
        )
        == "updated"
    )


# ============================================================
# Runtime Query / Get Verification
# ============================================================

def test_updated_item_can_be_read(
    table,
    runtime_item,
):
    response = table.get_item(
        Key=runtime_item["key"],
        ConsistentRead=True,
    )

    item = normalize_value(
        response.get(
            "Item",
            {},
        )
    )

    assert item

    assert (
        item.get(
            "status"
        )
        == "updated"
    )


# ============================================================
# Runtime Delete Test
# ============================================================

def test_delete_item(
    table,
    runtime_item,
):
    response = table.delete_item(
        Key=runtime_item["key"],
        ReturnValues="ALL_OLD",
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    old_item = response.get(
        "Attributes",
        {},
    )

    assert old_item


def test_deleted_item_is_not_found(
    table,
    runtime_item,
):
    response = table.get_item(
        Key=runtime_item["key"],
        ConsistentRead=True,
    )

    assert "Item" not in response