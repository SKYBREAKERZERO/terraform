import json
import os

import boto3
import pytest


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


@pytest.fixture(scope="session")
def sqs_client():
    return boto3.client(
        "sqs",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


def get_queue_url_or_none(
    client,
    queue_name,
):
    try:
        response = client.get_queue_url(
            QueueName=queue_name,
        )

    except client.exceptions.QueueDoesNotExist:
        return None

    return response.get(
        "QueueUrl"
    )


@pytest.fixture(scope="session")
def main_queue_url(
    sqs_client,
):
    queue_url = get_queue_url_or_none(
        sqs_client,
        EXPECTED_QUEUE_NAME,
    )

    assert queue_url is not None, (
        f"Main SQS queue not found: "
        f"{EXPECTED_QUEUE_NAME}"
    )

    return queue_url


@pytest.fixture(scope="session")
def main_queue_attributes(
    sqs_client,
    main_queue_url,
):
    response = sqs_client.get_queue_attributes(
        QueueUrl=main_queue_url,
        AttributeNames=[
            "All",
        ],
    )

    return response.get(
        "Attributes",
        {},
    )


@pytest.fixture(scope="session")
def main_queue_tags(
    sqs_client,
    main_queue_url,
):
    response = sqs_client.list_queue_tags(
        QueueUrl=main_queue_url,
    )

    return response.get(
        "Tags",
        {},
    )


@pytest.fixture(scope="session")
def dlq_url(
    sqs_client,
):
    return get_queue_url_or_none(
        sqs_client,
        EXPECTED_DLQ_NAME,
    )


@pytest.fixture(scope="session")
def dlq_attributes(
    sqs_client,
    dlq_url,
):
    if dlq_url is None:
        return None

    response = sqs_client.get_queue_attributes(
        QueueUrl=dlq_url,
        AttributeNames=[
            "All",
        ],
    )

    return response.get(
        "Attributes",
        {},
    )


@pytest.fixture(scope="session")
def dlq_tags(
    sqs_client,
    dlq_url,
):
    if dlq_url is None:
        return None

    response = sqs_client.list_queue_tags(
        QueueUrl=dlq_url,
    )

    return response.get(
        "Tags",
        {},
    )


def test_main_queue_exists(
    main_queue_url,
):
    assert main_queue_url


def test_main_queue_name(
    main_queue_url,
):
    actual_name = main_queue_url.rstrip(
        "/"
    ).rsplit(
        "/",
        1,
    )[-1]

    assert actual_name == EXPECTED_QUEUE_NAME


def test_main_queue_arn(
    main_queue_attributes,
):
    queue_arn = main_queue_attributes.get(
        "QueueArn"
    )

    assert queue_arn

    assert queue_arn.startswith(
        f"arn:aws:sqs:{AWS_REGION}:"
    )

    assert queue_arn.endswith(
        f":{EXPECTED_QUEUE_NAME}"
    )


def test_main_queue_fifo_configuration(
    main_queue_attributes,
):
    actual_fifo = main_queue_attributes.get(
        "FifoQueue",
        "false",
    ).lower()

    expected_fifo = (
        "true"
        if SQS_FIFO_QUEUE
        else "false"
    )

    assert actual_fifo == expected_fifo


def test_main_queue_fifo_name_suffix():
    if SQS_FIFO_QUEUE:
        assert EXPECTED_QUEUE_NAME.endswith(
            ".fifo"
        )
    else:
        assert not EXPECTED_QUEUE_NAME.endswith(
            ".fifo"
        )


def test_main_queue_content_based_deduplication(
    main_queue_attributes,
):
    actual = main_queue_attributes.get(
        "ContentBasedDeduplication",
        "false",
    ).lower()

    if SQS_FIFO_QUEUE:
        expected = (
            "true"
            if SQS_CONTENT_BASED_DEDUPLICATION
            else "false"
        )

        assert actual == expected

    else:
        assert actual == "false"


@pytest.mark.parametrize(
    (
        "attribute_name",
        "expected_value",
    ),
    [
        (
            "VisibilityTimeout",
            SQS_VISIBILITY_TIMEOUT_SECONDS,
        ),
        (
            "MessageRetentionPeriod",
            SQS_MESSAGE_RETENTION_SECONDS,
        ),
        (
            "ReceiveMessageWaitTimeSeconds",
            SQS_RECEIVE_WAIT_TIME_SECONDS,
        ),
        (
            "DelaySeconds",
            SQS_DELAY_SECONDS,
        ),
        (
            "MaximumMessageSize",
            SQS_MAX_MESSAGE_SIZE,
        ),
    ],
)
def test_main_queue_delivery_settings(
    main_queue_attributes,
    attribute_name,
    expected_value,
):
    actual_value = main_queue_attributes.get(
        attribute_name
    )

    assert actual_value is not None

    assert int(
        actual_value
    ) == expected_value


def test_main_queue_kms(
    main_queue_attributes,
):
    actual_kms = main_queue_attributes.get(
        "KmsMasterKeyId"
    )

    if SQS_KMS_MASTER_KEY_ID:
        assert (
            actual_kms
            == SQS_KMS_MASTER_KEY_ID
        )
    else:
        assert actual_kms in {
            None,
            "",
        }


@pytest.mark.parametrize(
    (
        "tag_name",
        "expected_value",
    ),
    list(
        EXPECTED_MAIN_TAGS.items()
    ),
)
def test_main_queue_tags(
    main_queue_tags,
    tag_name,
    expected_value,
):
    assert (
        main_queue_tags.get(
            tag_name
        )
        == expected_value
    )


def test_message_counters_exist(
    main_queue_attributes,
):
    counters = [
        "ApproximateNumberOfMessages",
        "ApproximateNumberOfMessagesNotVisible",
        "ApproximateNumberOfMessagesDelayed",
    ]

    for counter in counters:
        value = main_queue_attributes.get(
            counter,
            "0",
        )

        assert int(value) >= 0


def test_dlq_state(
    dlq_url,
):
    if SQS_DEAD_LETTER_QUEUE_ENABLED:
        assert dlq_url is not None
    else:
        assert dlq_url is None


def test_dlq_name(
    dlq_url,
):
    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        pytest.skip(
            "DLQ is disabled."
        )

    actual_name = dlq_url.rstrip(
        "/"
    ).rsplit(
        "/",
        1,
    )[-1]

    assert actual_name == EXPECTED_DLQ_NAME


def test_dlq_fifo_configuration(
    dlq_attributes,
):
    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        pytest.skip(
            "DLQ is disabled."
        )

    assert dlq_attributes is not None

    actual_fifo = dlq_attributes.get(
        "FifoQueue",
        "false",
    ).lower()

    expected_fifo = (
        "true"
        if SQS_FIFO_QUEUE
        else "false"
    )

    assert actual_fifo == expected_fifo


@pytest.mark.parametrize(
    (
        "tag_name",
        "expected_value",
    ),
    list(
        EXPECTED_DLQ_TAGS.items()
    ),
)
def test_dlq_tags(
    dlq_tags,
    tag_name,
    expected_value,
):
    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        pytest.skip(
            "DLQ is disabled."
        )

    assert dlq_tags is not None

    assert (
        dlq_tags.get(
            tag_name
        )
        == expected_value
    )


def test_redrive_policy_exists(
    main_queue_attributes,
):
    redrive_policy = main_queue_attributes.get(
        "RedrivePolicy"
    )

    if SQS_DEAD_LETTER_QUEUE_ENABLED:
        assert redrive_policy
    else:
        assert not redrive_policy


def test_redrive_policy_max_receive_count(
    main_queue_attributes,
):
    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        pytest.skip(
            "DLQ is disabled."
        )

    redrive_policy = json.loads(
        main_queue_attributes[
            "RedrivePolicy"
        ]
    )

    actual = int(
        redrive_policy[
            "maxReceiveCount"
        ]
    )

    assert (
        actual
        == SQS_MAX_RECEIVE_COUNT
    )


def test_redrive_policy_dlq_arn(
    main_queue_attributes,
    dlq_attributes,
):
    if not SQS_DEAD_LETTER_QUEUE_ENABLED:
        pytest.skip(
            "DLQ is disabled."
        )

    assert dlq_attributes is not None

    redrive_policy = json.loads(
        main_queue_attributes[
            "RedrivePolicy"
        ]
    )

    actual_dlq_arn = redrive_policy.get(
        "deadLetterTargetArn"
    )

    expected_dlq_arn = dlq_attributes.get(
        "QueueArn"
    )

    assert actual_dlq_arn
    assert expected_dlq_arn

    assert (
        actual_dlq_arn
        == expected_dlq_arn
    )