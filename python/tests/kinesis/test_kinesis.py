import os
import time
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

KINESIS_ENABLED = (
    os.getenv(
        "KINESIS_ENABLED",
        "true",
    ).lower()
    == "true"
)

KINESIS_STREAM_NAME = os.getenv(
    "KINESIS_STREAM_NAME",
)

EXPECTED_STREAM_NAME = (
    KINESIS_STREAM_NAME
    if KINESIS_STREAM_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-stream"
)


# ============================================================
# Expected Configuration
# ============================================================

EXPECTED_STREAM_MODE = os.getenv(
    "KINESIS_STREAM_MODE",
    "PROVISIONED",
)

EXPECTED_SHARD_COUNT = int(
    os.getenv(
        "KINESIS_SHARD_COUNT",
        "1",
    )
)

EXPECTED_RETENTION_PERIOD = int(
    os.getenv(
        "KINESIS_RETENTION_PERIOD",
        "24",
    )
)

EXPECTED_ENCRYPTION_TYPE = os.getenv(
    "KINESIS_ENCRYPTION_TYPE",
    "NONE",
)

EXPECTED_KMS_KEY_ID = (
    os.getenv(
        "KINESIS_KMS_KEY_ID",
        "",
    )
    or None
)

RAW_EXPECTED_METRICS = os.getenv(
    "KINESIS_SHARD_LEVEL_METRICS",
    "",
)

EXPECTED_SHARD_LEVEL_METRICS = {
    metric.strip()
    for metric in RAW_EXPECTED_METRICS.split(",")
    if metric.strip()
}


# ============================================================
# Runtime Test Record
# ============================================================

TEST_PARTITION_KEY = os.getenv(
    "KINESIS_TEST_PARTITION_KEY",
    "pytest-partition-001",
)

TEST_DATA = os.getenv(
    "KINESIS_TEST_DATA",
    "pytest-kinesis-smoke-test",
)

TEST_DATA_BYTES = TEST_DATA.encode(
    "utf-8"
)


# ============================================================
# Skip
# ============================================================

pytestmark = pytest.mark.skipif(
    not KINESIS_ENABLED,
    reason="Kinesis is disabled.",
)


# ============================================================
# Client
# ============================================================

@pytest.fixture(scope="session")
def kinesis_client():
    return boto3.client(
        "kinesis",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# Stream Fixtures
# ============================================================

@pytest.fixture(scope="session")
def stream_summary(
    kinesis_client,
) -> dict[str, Any]:
    response = (
        kinesis_client.describe_stream_summary(
            StreamName=EXPECTED_STREAM_NAME,
        )
    )

    return response[
        "StreamDescriptionSummary"
    ]


@pytest.fixture(scope="session")
def stream_shards(
    kinesis_client,
) -> list[dict[str, Any]]:
    shards: list[dict[str, Any]] = []

    next_token = None

    while True:
        if next_token:
            response = kinesis_client.list_shards(
                NextToken=next_token,
            )
        else:
            response = kinesis_client.list_shards(
                StreamName=EXPECTED_STREAM_NAME,
            )

        shards.extend(
            response.get(
                "Shards",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return shards


# ============================================================
# API Tests
# ============================================================

def test_kinesis_api_available(
    kinesis_client,
):
    response = kinesis_client.list_streams(
        Limit=1,
    )

    status_code = response[
        "ResponseMetadata"
    ][
        "HTTPStatusCode"
    ]

    assert status_code == 200


def test_stream_exists(
    stream_summary,
):
    assert (
        stream_summary["StreamName"]
        == EXPECTED_STREAM_NAME
    )


def test_stream_active(
    stream_summary,
):
    assert (
        stream_summary["StreamStatus"]
        == "ACTIVE"
    )


def test_stream_arn_exists(
    stream_summary,
):
    stream_arn = stream_summary.get(
        "StreamARN"
    )

    assert stream_arn
    assert EXPECTED_STREAM_NAME in stream_arn


# ============================================================
# Stream Mode Tests
# ============================================================

def test_stream_mode(
    stream_summary,
):
    mode_details = stream_summary.get(
        "StreamModeDetails",
        {},
    )

    actual_mode = mode_details.get(
        "StreamMode"
    )

    if actual_mode is None:
        if EXPECTED_STREAM_MODE == "PROVISIONED":
            pytest.skip(
                "StreamModeDetails not returned "
                "by LocalStack."
            )

    assert (
        actual_mode
        == EXPECTED_STREAM_MODE
    )


# ============================================================
# Shard Tests
# ============================================================

def test_stream_has_shards(
    stream_shards,
):
    assert len(
        stream_shards
    ) >= 1


def test_shard_count(
    stream_shards,
):
    if EXPECTED_STREAM_MODE == "ON_DEMAND":
        pytest.skip(
            "Shard count is managed by "
            "ON_DEMAND mode."
        )

    assert (
        len(stream_shards)
        == EXPECTED_SHARD_COUNT
    )


def test_open_shard_count(
    stream_summary,
    stream_shards,
):
    actual = stream_summary.get(
        "OpenShardCount"
    )

    if actual is None:
        pytest.skip(
            "OpenShardCount not returned."
        )

    assert (
        actual
        == len(stream_shards)
    )


def test_shards_have_valid_hash_ranges(
    stream_shards,
):
    for shard in stream_shards:
        assert shard.get(
            "ShardId"
        )

        hash_range = shard.get(
            "HashKeyRange",
            {},
        )

        assert (
            hash_range.get(
                "StartingHashKey"
            )
            is not None
        )

        assert (
            hash_range.get(
                "EndingHashKey"
            )
            is not None
        )


# ============================================================
# Retention Test
# ============================================================

def test_retention_period(
    stream_summary,
):
    assert (
        stream_summary.get(
            "RetentionPeriodHours"
        )
        == EXPECTED_RETENTION_PERIOD
    )


# ============================================================
# Encryption Tests
# ============================================================

def test_encryption_type(
    stream_summary,
):
    actual = stream_summary.get(
        "EncryptionType"
    )

    if actual is None:
        actual = "NONE"

    assert (
        actual
        == EXPECTED_ENCRYPTION_TYPE
    )


def test_kms_key(
    stream_summary,
):
    if EXPECTED_ENCRYPTION_TYPE != "KMS":
        pytest.skip(
            "KMS encryption is not enabled."
        )

    actual_key_id = stream_summary.get(
        "KeyId"
    )

    assert actual_key_id

    if EXPECTED_KMS_KEY_ID:
        assert (
            actual_key_id
            == EXPECTED_KMS_KEY_ID
        )


# ============================================================
# Enhanced Monitoring Test
# ============================================================

def test_shard_level_metrics(
    stream_summary,
):
    enhanced_monitoring = stream_summary.get(
        "EnhancedMonitoring",
        [],
    )

    actual_metrics: set[str] = set()

    for item in enhanced_monitoring:
        actual_metrics.update(
            item.get(
                "ShardLevelMetrics",
                [],
            )
        )

    assert (
        actual_metrics
        == EXPECTED_SHARD_LEVEL_METRICS
    )


# ============================================================
# Runtime PutRecord Fixture
# ============================================================

@pytest.fixture(scope="session")
def runtime_record(
    kinesis_client,
):
    response = kinesis_client.put_record(
        StreamName=EXPECTED_STREAM_NAME,
        Data=TEST_DATA_BYTES,
        PartitionKey=TEST_PARTITION_KEY,
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    shard_id = response.get(
        "ShardId"
    )

    sequence_number = response.get(
        "SequenceNumber"
    )

    assert shard_id
    assert sequence_number

    return {
        "shard_id": shard_id,
        "sequence_number": sequence_number,
        "partition_key": TEST_PARTITION_KEY,
        "data": TEST_DATA_BYTES,
    }


# ============================================================
# Runtime PutRecord Tests
# ============================================================

def test_put_record_returns_shard(
    runtime_record,
):
    assert runtime_record[
        "shard_id"
    ]


def test_put_record_returns_sequence_number(
    runtime_record,
):
    assert runtime_record[
        "sequence_number"
    ]


# ============================================================
# Runtime GetShardIterator
# ============================================================

@pytest.fixture(scope="session")
def shard_iterator(
    kinesis_client,
    runtime_record,
):
    response = (
        kinesis_client.get_shard_iterator(
            StreamName=EXPECTED_STREAM_NAME,
            ShardId=runtime_record[
                "shard_id"
            ],
            ShardIteratorType=(
                "AT_SEQUENCE_NUMBER"
            ),
            StartingSequenceNumber=(
                runtime_record[
                    "sequence_number"
                ]
            ),
        )
    )

    iterator = response.get(
        "ShardIterator"
    )

    assert iterator

    return iterator


def test_get_shard_iterator(
    shard_iterator,
):
    assert shard_iterator


# ============================================================
# Runtime GetRecords
# ============================================================

@pytest.fixture(scope="session")
def consumed_record(
    kinesis_client,
    shard_iterator,
    runtime_record,
):
    current_iterator = shard_iterator

    timeout_seconds = 10
    poll_interval = 0.5

    deadline = (
        time.monotonic()
        + timeout_seconds
    )

    while time.monotonic() < deadline:
        response = kinesis_client.get_records(
            ShardIterator=current_iterator,
            Limit=100,
        )

        records = response.get(
            "Records",
            [],
        )

        for record in records:
            if (
                record.get(
                    "SequenceNumber"
                )
                == runtime_record[
                    "sequence_number"
                ]
            ):
                return record

        current_iterator = response.get(
            "NextShardIterator"
        )

        if not current_iterator:
            break

        time.sleep(
            poll_interval
        )

    pytest.fail(
        "Unable to consume the record written "
        "during the smoke test within "
        f"{timeout_seconds} seconds."
    )


def test_get_records_returns_test_record(
    consumed_record,
):
    assert consumed_record


def test_consumed_sequence_number(
    consumed_record,
    runtime_record,
):
    assert (
        consumed_record.get(
            "SequenceNumber"
        )
        == runtime_record[
            "sequence_number"
        ]
    )


def test_consumed_partition_key(
    consumed_record,
    runtime_record,
):
    assert (
        consumed_record.get(
            "PartitionKey"
        )
        == runtime_record[
            "partition_key"
        ]
    )


def test_consumed_data(
    consumed_record,
    runtime_record,
):
    actual_data = consumed_record.get(
        "Data"
    )

    assert actual_data

    assert (
        bytes(actual_data)
        == runtime_record[
            "data"
        ]
    )


def test_consumed_data_decodes_correctly(
    consumed_record,
):
    actual_data = consumed_record[
        "Data"
    ]

    assert (
        bytes(actual_data).decode(
            "utf-8"
        )
        == TEST_DATA
    )


# ============================================================
# PutRecords Batch Test
# ============================================================

def test_put_records_batch(
    kinesis_client,
):
    records = [
        {
            "Data": (
                f"{TEST_DATA}-batch-{index}"
            ).encode(
                "utf-8"
            ),
            "PartitionKey": (
                f"{TEST_PARTITION_KEY}-"
                f"{index}"
            ),
        }
        for index in range(
            1,
            4,
        )
    ]

    response = kinesis_client.put_records(
        StreamName=EXPECTED_STREAM_NAME,
        Records=records,
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    assert (
        response.get(
            "FailedRecordCount",
            0,
        )
        == 0
    )

    result_records = response.get(
        "Records",
        [],
    )

    assert len(
        result_records
    ) == 3

    for result in result_records:
        assert result.get(
            "ShardId"
        )

        assert result.get(
            "SequenceNumber"
        )


# ============================================================
# Consumer API Test
# ============================================================

def test_list_stream_consumers(
    kinesis_client,
    stream_summary,
):
    stream_arn = stream_summary.get(
        "StreamARN"
    )

    if not stream_arn:
        pytest.skip(
            "Stream ARN unavailable."
        )

    try:
        response = (
            kinesis_client.list_stream_consumers(
                StreamARN=stream_arn,
            )
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        pytest.skip(
            "Enhanced fan-out consumer API "
            "is unavailable in LocalStack: "
            f"{error}"
        )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    assert isinstance(
        response.get(
            "Consumers",
            [],
        ),
        list,
    )