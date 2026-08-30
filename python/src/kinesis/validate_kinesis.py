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
    item.strip()
    for item in RAW_EXPECTED_METRICS.split(",")
    if item.strip()
}

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_STREAM_NAME,
    "Component": "streaming",
    "Service": "kinesis",
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

kinesis = boto3.client(
    "kinesis",
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
# API Helpers
# ============================================================

def get_stream_summary() -> dict[str, Any]:
    response = kinesis.describe_stream_summary(
        StreamName=EXPECTED_STREAM_NAME,
    )

    return response.get(
        "StreamDescriptionSummary",
        {},
    )


def get_shards() -> list[dict[str, Any]]:
    shards: list[dict[str, Any]] = []

    next_token = None

    while True:
        if next_token:
            response = kinesis.list_shards(
                NextToken=next_token,
            )

        else:
            response = kinesis.list_shards(
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


def get_tags() -> dict[str, str]:
    tags: list[dict[str, str]] = []

    exclusive_start_tag_key = None

    while True:
        request: dict[str, Any] = {
            "StreamName": EXPECTED_STREAM_NAME,
            "Limit": 50,
        }

        if exclusive_start_tag_key:
            request[
                "ExclusiveStartTagKey"
            ] = exclusive_start_tag_key

        response = kinesis.list_tags_for_stream(
            **request
        )

        page_tags = response.get(
            "Tags",
            [],
        )

        tags.extend(
            page_tags
        )

        has_more = response.get(
            "HasMoreTags",
            False,
        )

        if not has_more:
            break

        if not page_tags:
            break

        exclusive_start_tag_key = (
            page_tags[-1]["Key"]
        )

    return {
        item.get("Key"): item.get("Value")
        for item in tags
        if item.get("Key")
    }


# ============================================================
# General Validation
# ============================================================

def validate_general(
    summary: dict[str, Any],
) -> None:
    print()
    print("GENERAL")
    print("-" * 70)

    check_equal(
        "Stream name",
        summary.get(
            "StreamName"
        ),
        EXPECTED_STREAM_NAME,
    )

    check_equal(
        "Stream status",
        summary.get(
            "StreamStatus"
        ),
        "ACTIVE",
    )

    stream_arn = summary.get(
        "StreamARN"
    )

    if stream_arn:
        pass_check(
            f"Stream ARN exists: {stream_arn}"
        )

    else:
        fail_check(
            "Stream ARN is missing."
        )

    creation_timestamp = summary.get(
        "StreamCreationTimestamp"
    )

    if creation_timestamp:
        pass_check(
            "Stream creation timestamp exists."
        )

    else:
        warn_check(
            "Stream creation timestamp "
            "was not returned."
        )


# ============================================================
# Stream Mode Validation
# ============================================================

def validate_stream_mode(
    summary: dict[str, Any],
) -> None:
    print()
    print("STREAM MODE")
    print("-" * 70)

    mode_details = summary.get(
        "StreamModeDetails",
        {},
    )

    actual_mode = mode_details.get(
        "StreamMode"
    )

    if actual_mode is None:
        if EXPECTED_STREAM_MODE == "PROVISIONED":
            warn_check(
                "StreamModeDetails was not returned; "
                "assuming PROVISIONED for emulator compatibility."
            )

        else:
            fail_check(
                "StreamModeDetails is missing for "
                f"expected mode {EXPECTED_STREAM_MODE}."
            )

        return

    check_equal(
        "Stream mode",
        actual_mode,
        EXPECTED_STREAM_MODE,
    )


# ============================================================
# Shard Validation
# ============================================================

def validate_shards(
    summary: dict[str, Any],
    shards: list[dict[str, Any]],
) -> None:
    print()
    print("SHARDS")
    print("-" * 70)

    actual_count = len(
        shards
    )

    summary_count = summary.get(
        "OpenShardCount"
    )

    if summary_count is not None:
        check_equal(
            "Open shard count",
            summary_count,
            actual_count,
        )

    else:
        warn_check(
            "OpenShardCount was not returned."
        )

    if EXPECTED_STREAM_MODE == "PROVISIONED":
        check_equal(
            "Configured shard count",
            actual_count,
            EXPECTED_SHARD_COUNT,
        )

    else:
        if actual_count >= 1:
            pass_check(
                f"ON_DEMAND stream has "
                f"{actual_count} open shard(s)."
            )

        else:
            fail_check(
                "ON_DEMAND stream has no shards."
            )

    for shard in shards:
        shard_id = shard.get(
            "ShardId"
        )

        if not shard_id:
            fail_check(
                "A shard is missing ShardId."
            )
            continue

        hash_range = shard.get(
            "HashKeyRange",
            {},
        )

        start_hash = hash_range.get(
            "StartingHashKey"
        )

        end_hash = hash_range.get(
            "EndingHashKey"
        )

        if (
            start_hash is not None
            and end_hash is not None
        ):
            pass_check(
                f"Shard {shard_id} has a valid "
                "HashKeyRange."
            )

        else:
            fail_check(
                f"Shard {shard_id} is missing "
                "HashKeyRange."
            )


# ============================================================
# Retention Validation
# ============================================================

def validate_retention(
    summary: dict[str, Any],
) -> None:
    print()
    print("RETENTION")
    print("-" * 70)

    check_equal(
        "Retention period",
        summary.get(
            "RetentionPeriodHours"
        ),
        EXPECTED_RETENTION_PERIOD,
    )


# ============================================================
# Encryption Validation
# ============================================================

def validate_encryption(
    summary: dict[str, Any],
) -> None:
    print()
    print("SERVER-SIDE ENCRYPTION")
    print("-" * 70)

    actual_type = summary.get(
        "EncryptionType",
        "NONE",
    )

    check_equal(
        "Encryption type",
        actual_type,
        EXPECTED_ENCRYPTION_TYPE,
    )

    actual_key_id = summary.get(
        "KeyId"
    )

    if EXPECTED_ENCRYPTION_TYPE == "KMS":
        if actual_key_id:
            pass_check(
                f"KMS key returned: {actual_key_id}"
            )

        else:
            fail_check(
                "KMS encryption is expected but "
                "KeyId is missing."
            )

        if EXPECTED_KMS_KEY_ID:
            if (
                actual_key_id
                == EXPECTED_KMS_KEY_ID
            ):
                pass_check(
                    "KMS key matches expected value."
                )

            elif (
                EXPECTED_KMS_KEY_ID
                in str(actual_key_id)
                or str(actual_key_id)
                in EXPECTED_KMS_KEY_ID
            ):
                warn_check(
                    "KMS key representation differs "
                    "but appears to refer to the same key."
                )

            else:
                fail_check(
                    "KMS key mismatch: "
                    f"expected={EXPECTED_KMS_KEY_ID!r}, "
                    f"actual={actual_key_id!r}"
                )

        else:
            pass_check(
                "Strict KMS key matching is disabled."
            )

    else:
        if actual_key_id:
            warn_check(
                "Encryption type is NONE but "
                f"KeyId was returned: {actual_key_id}"
            )

        else:
            pass_check(
                "No KMS key configured."
            )


# ============================================================
# Enhanced Monitoring Validation
# ============================================================

def validate_metrics(
    summary: dict[str, Any],
) -> None:
    print()
    print("SHARD-LEVEL METRICS")
    print("-" * 70)

    monitoring = summary.get(
        "EnhancedMonitoring",
        [],
    )

    actual_metrics: set[str] = set()

    for item in monitoring:
        actual_metrics.update(
            item.get(
                "ShardLevelMetrics",
                [],
            )
        )

    if (
        EXPECTED_SHARD_LEVEL_METRICS
        == actual_metrics
    ):
        if actual_metrics:
            pass_check(
                "Shard-level metrics match: "
                + ", ".join(
                    sorted(actual_metrics)
                )
            )

        else:
            pass_check(
                "No shard-level metrics configured."
            )

        return

    missing = (
        EXPECTED_SHARD_LEVEL_METRICS
        - actual_metrics
    )

    unexpected = (
        actual_metrics
        - EXPECTED_SHARD_LEVEL_METRICS
    )

    if missing:
        fail_check(
            "Missing shard-level metrics: "
            + ", ".join(
                sorted(missing)
            )
        )

    if unexpected:
        fail_check(
            "Unexpected shard-level metrics: "
            + ", ".join(
                sorted(unexpected)
            )
        )


# ============================================================
# Tag Validation
# ============================================================

def validate_tags() -> None:
    print()
    print("TAGS")
    print("-" * 70)

    try:
        tags = get_tags()

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "Tag API is unavailable or unsupported: "
            f"{error}"
        )
        return

    for key, expected_value in (
        EXPECTED_TAGS.items()
    ):
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
# Consumer Validation
# ============================================================

def validate_consumers(
    summary: dict[str, Any],
) -> None:
    print()
    print("ENHANCED FAN-OUT")
    print("-" * 70)

    stream_arn = summary.get(
        "StreamARN"
    )

    if not stream_arn:
        warn_check(
            "Cannot inspect consumers because "
            "StreamARN is missing."
        )
        return

    try:
        response = kinesis.list_stream_consumers(
            StreamARN=stream_arn,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "Enhanced fan-out consumer API "
            f"is unavailable: {error}"
        )
        return

    consumers = response.get(
        "Consumers",
        [],
    )

    if not consumers:
        pass_check(
            "No enhanced fan-out consumers configured."
        )

    else:
        warn_check(
            "Enhanced fan-out consumers exist, "
            f"count={len(consumers)}."
        )


# ============================================================
# Summary
# ============================================================

def print_summary() -> None:
    print()
    print("=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)

    print(
        f"PASS : {PASS_COUNT}"
    )

    print(
        f"WARN : {WARN_COUNT}"
    )

    print(
        f"FAIL : {FAIL_COUNT}"
    )

    print("=" * 70)

    if FAIL_COUNT == 0:
        print(
            "[PASS] Kinesis validation successful."
        )

    else:
        print(
            "[FAIL] Kinesis validation failed."
        )


# ============================================================
# Main
# ============================================================

def main() -> int:
    print("=" * 70)
    print("KINESIS VALIDATION")
    print("=" * 70)

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
        f"Stream:       {EXPECTED_STREAM_NAME}"
    )

    if not KINESIS_ENABLED:
        print()
        pass_check(
            "Kinesis is disabled."
        )

        print_summary()

        return 0

    try:
        summary = get_stream_summary()
        shards = get_shards()

    except ClientError as error:
        error_info = error.response.get(
            "Error",
            {},
        )

        fail_check(
            "Unable to retrieve Kinesis stream: "
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
            "Unexpected error while retrieving "
            "Kinesis stream: "
            f"{type(error).__name__}: {error}"
        )

        print_summary()

        return 1

    validate_general(
        summary
    )

    validate_stream_mode(
        summary
    )

    validate_shards(
        summary,
        shards,
    )

    validate_retention(
        summary
    )

    validate_encryption(
        summary
    )

    validate_metrics(
        summary
    )

    validate_consumers(
        summary
    )

    validate_tags()

    print_summary()

    return (
        0
        if FAIL_COUNT == 0
        else 1
    )


if __name__ == "__main__":
    sys.exit(
        main()
    )