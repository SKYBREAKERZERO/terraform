import json
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


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

SQS_QUEUE_NAME = os.getenv(
    "SQS_QUEUE_NAME",
)

SQS_FIFO_QUEUE = os.getenv(
    "SQS_FIFO_QUEUE",
    "false",
).lower() == "true"

SQS_CONTENT_BASED_DEDUPLICATION = os.getenv(
    "SQS_CONTENT_BASED_DEDUPLICATION",
    "false",
).lower() == "true"

SQS_KMS_MASTER_KEY_ID = os.getenv(
    "SQS_KMS_MASTER_KEY_ID",
)

SQS_DEAD_LETTER_QUEUE_ENABLED = os.getenv(
    "SQS_DEAD_LETTER_QUEUE_ENABLED",
    "true",
).lower() == "true"

SQS_MAX_RECEIVE_COUNT = int(
    os.getenv(
        "SQS_MAX_RECEIVE_COUNT",
        "5",
    )
)

SQS_VISIBILITY_TIMEOUT_SECONDS = int(
    os.getenv(
        "SQS_VISIBILITY_TIMEOUT_SECONDS",
        "30",
    )
)

SQS_MESSAGE_RETENTION_SECONDS = int(
    os.getenv(
        "SQS_MESSAGE_RETENTION_SECONDS",
        "345600",
    )
)

SQS_RECEIVE_WAIT_TIME_SECONDS = int(
    os.getenv(
        "SQS_RECEIVE_WAIT_TIME_SECONDS",
        "20",
    )
)

SQS_DELAY_SECONDS = int(
    os.getenv(
        "SQS_DELAY_SECONDS",
        "0",
    )
)

SQS_MAX_MESSAGE_SIZE = int(
    os.getenv(
        "SQS_MAX_MESSAGE_SIZE",
        "262144",
    )
)


BASE_QUEUE_NAME = (
    SQS_QUEUE_NAME
    if SQS_QUEUE_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-queue"
)

EXPECTED_QUEUE_NAME = (
    BASE_QUEUE_NAME
    if (
        not SQS_FIFO_QUEUE
        or BASE_QUEUE_NAME.endswith(".fifo")
    )
    else f"{BASE_QUEUE_NAME}.fifo"
)

BASE_DLQ_NAME = (
    EXPECTED_QUEUE_NAME.removesuffix(".fifo")
    if SQS_FIFO_QUEUE
    else EXPECTED_QUEUE_NAME
)

EXPECTED_DLQ_NAME = (
    f"{BASE_DLQ_NAME}-dlq.fifo"
    if SQS_FIFO_QUEUE
    else f"{BASE_DLQ_NAME}-dlq"
)


EXPECTED_MAIN_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Component": "messaging",
    "Service": "sqs",
    "QueueType": "main",
}

EXPECTED_DLQ_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Component": "messaging",
    "Service": "sqs",
    "QueueType": "dlq",
}


PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(message):
    global PASS_COUNT

    PASS_COUNT += 1
    print(f"[PASS] {message}")


def warn_check(message):
    global WARN_COUNT

    WARN_COUNT += 1
    print(f"[WARN] {message}")


def fail_check(message):
    global FAIL_COUNT

    FAIL_COUNT += 1
    print(f"[FAIL] {message}")


def create_sqs_client():
    return boto3.client(
        "sqs",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


def get_queue_url(
    client,
    queue_name,
):
    try:
        response = client.get_queue_url(
            QueueName=queue_name,
        )

    except ClientError as error:
        error_code = (
            error.response
            .get("Error", {})
            .get("Code", "")
        )

        if error_code in {
            "AWS.SimpleQueueService.NonExistentQueue",
            "QueueDoesNotExist",
        }:
            return None

        raise

    return response.get(
        "QueueUrl"
    )


def get_queue_attributes(
    client,
    queue_url,
):
    response = client.get_queue_attributes(
        QueueUrl=queue_url,
        AttributeNames=[
            "All",
        ],
    )

    return response.get(
        "Attributes",
        {},
    )


def get_queue_tags(
    client,
    queue_url,
):
    response = client.list_queue_tags(
        QueueUrl=queue_url,
    )

    return response.get(
        "Tags",
        {},
    )


def get_queue_info(
    client,
    queue_name,
):
    queue_url = get_queue_url(
        client,
        queue_name,
    )

    if not queue_url:
        return None

    attributes = get_queue_attributes(
        client,
        queue_url,
    )

    tags = get_queue_tags(
        client,
        queue_url,
    )

    return {
        "name": queue_name,
        "url": queue_url,
        "attributes": attributes,
        "tags": tags,
    }


def validate_queue_exists(
    queue,
    expected_name,
    queue_type,
):
    if not queue:
        fail_check(
            f"{queue_type} not found: {expected_name}"
        )
        return False

    pass_check(
        f"{queue_type} exists: {expected_name}"
    )

    return True


def validate_queue_identity(
    queue,
):
    queue_url = queue["url"]
    attributes = queue["attributes"]

    if queue["name"] == EXPECTED_QUEUE_NAME:
        pass_check(
            f"Main queue name is correct: {queue['name']}"
        )
    else:
        fail_check(
            f"Unexpected main queue name: {queue['name']}"
        )

    if queue_url:
        pass_check(
            "Main queue URL exists"
        )
    else:
        fail_check(
            "Main queue URL is missing"
        )

    queue_arn = attributes.get(
        "QueueArn"
    )

    if queue_arn:
        pass_check(
            f"Main queue ARN exists: {queue_arn}"
        )
    else:
        fail_check(
            "Main queue ARN is missing"
        )


def validate_fifo(
    attributes,
    queue_type,
):
    actual_fifo = attributes.get(
        "FifoQueue",
        "false",
    ).lower()

    expected_fifo = (
        "true"
        if SQS_FIFO_QUEUE
        else "false"
    )

    if actual_fifo == expected_fifo:
        pass_check(
            f"{queue_type} FIFO configuration is {expected_fifo}"
        )
    else:
        fail_check(
            f"{queue_type} FIFO expected "
            f"{expected_fifo}, got {actual_fifo}"
        )

    actual_dedup = attributes.get(
        "ContentBasedDeduplication",
        "false",
    ).lower()

    if SQS_FIFO_QUEUE:
        expected_dedup = (
            "true"
            if SQS_CONTENT_BASED_DEDUPLICATION
            else "false"
        )

        if actual_dedup == expected_dedup:
            pass_check(
                f"{queue_type} content-based deduplication "
                f"is {expected_dedup}"
            )
        else:
            fail_check(
                f"{queue_type} content-based deduplication "
                f"expected {expected_dedup}, got {actual_dedup}"
            )

    else:
        if actual_dedup == "false":
            pass_check(
                f"{queue_type} content-based deduplication "
                "is disabled"
            )
        else:
            fail_check(
                f"{queue_type} content-based deduplication "
                "should be disabled for Standard queue"
            )


def validate_delivery_settings(
    attributes,
    queue_type,
):
    checks = {
        "VisibilityTimeout":
            SQS_VISIBILITY_TIMEOUT_SECONDS,

        "MessageRetentionPeriod":
            SQS_MESSAGE_RETENTION_SECONDS,

        "ReceiveMessageWaitTimeSeconds":
            SQS_RECEIVE_WAIT_TIME_SECONDS,

        "DelaySeconds":
            SQS_DELAY_SECONDS,

        "MaximumMessageSize":
            SQS_MAX_MESSAGE_SIZE,
    }

    for attribute_name, expected_value in checks.items():
        actual_value = attributes.get(
            attribute_name
        )

        if actual_value is None:
            fail_check(
                f"{queue_type} missing attribute: "
                f"{attribute_name}"
            )
            continue

        try:
            actual_value = int(
                actual_value
            )

        except ValueError:
            fail_check(
                f"{queue_type} invalid value for "
                f"{attribute_name}: {actual_value}"
            )
            continue

        if actual_value == expected_value:
            pass_check(
                f"{queue_type} {attribute_name}="
                f"{expected_value}"
            )
        else:
            fail_check(
                f"{queue_type} {attribute_name} "
                f"expected {expected_value}, "
                f"got {actual_value}"
            )


def validate_kms(
    attributes,
    queue_type,
):
    actual_kms = attributes.get(
        "KmsMasterKeyId"
    )

    if SQS_KMS_MASTER_KEY_ID:
        if actual_kms == SQS_KMS_MASTER_KEY_ID:
            pass_check(
                f"{queue_type} KMS key matches expected value"
            )
        else:
            fail_check(
                f"{queue_type} KMS key expected "
                f"{SQS_KMS_MASTER_KEY_ID}, "
                f"got {actual_kms}"
            )

    else:
        if actual_kms:
            warn_check(
                f"{queue_type} uses KMS encryption "
                f"but no expected key was configured: "
                f"{actual_kms}"
            )
        else:
            pass_check(
                f"{queue_type} has no custom KMS key"
            )


def validate_tags(
    tags,
    expected_tags,
    queue_type,
):
    if not tags:
        fail_check(
            f"{queue_type} has no tags"
        )
        return

    pass_check(
        f"{queue_type} has tags"
    )

    for key, expected_value in expected_tags.items():
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"{queue_type} tag "
                f"{key}={expected_value}"
            )
        elif actual_value is None:
            fail_check(
                f"{queue_type} required tag missing: {key}"
            )
        else:
            fail_check(
                f"{queue_type} tag {key} expected "
                f"{expected_value}, got {actual_value}"
            )


def validate_redrive_policy(
    main_queue,
    dlq,
):
    attributes = main_queue["attributes"]

    redrive_policy_raw = attributes.get(
        "RedrivePolicy"
    )

    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        if redrive_policy_raw:
            fail_check(
                "RedrivePolicy exists but DLQ is disabled"
            )
        else:
            pass_check(
                "RedrivePolicy is disabled"
            )

        return

    if not redrive_policy_raw:
        fail_check(
            "Main queue RedrivePolicy is missing"
        )
        return

    pass_check(
        "Main queue RedrivePolicy exists"
    )

    try:
        redrive_policy = json.loads(
            redrive_policy_raw
        )

    except json.JSONDecodeError:
        fail_check(
            "Main queue RedrivePolicy is invalid JSON"
        )
        return

    actual_max_receive_count = redrive_policy.get(
        "maxReceiveCount"
    )

    try:
        actual_max_receive_count = int(
            actual_max_receive_count
        )

    except (
        TypeError,
        ValueError,
    ):
        fail_check(
            "RedrivePolicy maxReceiveCount is invalid"
        )

    else:
        if (
            actual_max_receive_count
            == SQS_MAX_RECEIVE_COUNT
        ):
            pass_check(
                "RedrivePolicy maxReceiveCount="
                f"{SQS_MAX_RECEIVE_COUNT}"
            )
        else:
            fail_check(
                "RedrivePolicy maxReceiveCount expected "
                f"{SQS_MAX_RECEIVE_COUNT}, "
                f"got {actual_max_receive_count}"
            )

    if not dlq:
        fail_check(
            "DLQ is enabled but queue does not exist"
        )
        return

    expected_dlq_arn = (
        dlq["attributes"].get(
            "QueueArn"
        )
    )

    actual_dlq_arn = redrive_policy.get(
        "deadLetterTargetArn"
    )

    if actual_dlq_arn == expected_dlq_arn:
        pass_check(
            "RedrivePolicy deadLetterTargetArn "
            "matches DLQ ARN"
        )
    else:
        fail_check(
            "RedrivePolicy deadLetterTargetArn "
            f"expected {expected_dlq_arn}, "
            f"got {actual_dlq_arn}"
        )


def validate_message_counters(
    attributes,
    queue_type,
):
    counters = [
        "ApproximateNumberOfMessages",
        "ApproximateNumberOfMessagesNotVisible",
        "ApproximateNumberOfMessagesDelayed",
    ]

    for counter in counters:
        value = attributes.get(
            counter,
            "0",
        )

        try:
            numeric_value = int(
                value
            )

        except ValueError:
            warn_check(
                f"{queue_type} {counter} "
                f"is not numeric: {value}"
            )
            continue

        if numeric_value >= 0:
            pass_check(
                f"{queue_type} {counter}="
                f"{numeric_value}"
            )
        else:
            fail_check(
                f"{queue_type} {counter} "
                "must not be negative"
            )


def print_summary():
    print()
    print("=" * 70)
    print("SQS VALIDATION SUMMARY")
    print("=" * 70)

    print(
        f"PASS: {PASS_COUNT}"
    )

    print(
        f"WARN: {WARN_COUNT}"
    )

    print(
        f"FAIL: {FAIL_COUNT}"
    )


def run():
    client = create_sqs_client()

    main_queue = get_queue_info(
        client,
        EXPECTED_QUEUE_NAME,
    )

    if not validate_queue_exists(
        main_queue,
        EXPECTED_QUEUE_NAME,
        "Main queue",
    ):
        return

    validate_queue_identity(
        main_queue
    )

    validate_fifo(
        main_queue["attributes"],
        "Main queue",
    )

    validate_delivery_settings(
        main_queue["attributes"],
        "Main queue",
    )

    validate_kms(
        main_queue["attributes"],
        "Main queue",
    )

    validate_tags(
        main_queue["tags"],
        EXPECTED_MAIN_TAGS,
        "Main queue",
    )

    validate_message_counters(
        main_queue["attributes"],
        "Main queue",
    )

    dlq = get_queue_info(
        client,
        EXPECTED_DLQ_NAME,
    )

    if SQS_DEAD_LETTER_QUEUE_ENABLED:
        dlq_exists = validate_queue_exists(
            dlq,
            EXPECTED_DLQ_NAME,
            "DLQ",
        )

        if dlq_exists:
            validate_fifo(
                dlq["attributes"],
                "DLQ",
            )

            validate_delivery_settings(
                dlq["attributes"],
                "DLQ",
            )

            validate_kms(
                dlq["attributes"],
                "DLQ",
            )

            validate_tags(
                dlq["tags"],
                EXPECTED_DLQ_TAGS,
                "DLQ",
            )

            validate_message_counters(
                dlq["attributes"],
                "DLQ",
            )

    else:
        if dlq:
            fail_check(
                f"DLQ exists but is disabled: {EXPECTED_DLQ_NAME}"
            )
        else:
            pass_check(
                "DLQ is disabled and no DLQ exists"
            )

    validate_redrive_policy(
        main_queue,
        dlq,
    )


def main():
    try:
        run()

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

        fail_check(
            "AWS API error: "
            f"{error_code}: {error_message}"
        )

    except BotoCoreError as error:
        fail_check(
            f"AWS SDK error: {error}"
        )

    except (
        TypeError,
        ValueError,
    ) as error:
        fail_check(
            f"Configuration error: {error}"
        )

    except KeyboardInterrupt:
        print()
        print(
            "[INFO] Interrupted by user."
        )

        return 130

    print_summary()

    if FAIL_COUNT > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(
        main()
    )