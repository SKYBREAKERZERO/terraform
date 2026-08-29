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

SNS_TOPIC_NAME = os.getenv(
    "SNS_TOPIC_NAME",
)

SNS_FIFO_TOPIC = os.getenv(
    "SNS_FIFO_TOPIC",
    "false",
).lower() == "true"

SNS_CONTENT_BASED_DEDUPLICATION = os.getenv(
    "SNS_CONTENT_BASED_DEDUPLICATION",
    "false",
).lower() == "true"

SNS_KMS_MASTER_KEY_ID = os.getenv(
    "SNS_KMS_MASTER_KEY_ID",
)

BASE_TOPIC_NAME = (
    SNS_TOPIC_NAME
    if SNS_TOPIC_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-alerts"
)

EXPECTED_TOPIC_NAME = (
    BASE_TOPIC_NAME
    if (
        not SNS_FIFO_TOPIC
        or BASE_TOPIC_NAME.endswith(".fifo")
    )
    else f"{BASE_TOPIC_NAME}.fifo"
)


# ============================================================
# Fixtures
# ============================================================

@pytest.fixture(scope="session")
def sns_client():
    return boto3.client(
        "sns",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


@pytest.fixture(scope="session")
def topics(
    sns_client,
):
    topics = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["NextToken"] = next_token

        response = sns_client.list_topics(
            **kwargs
        )

        topics.extend(
            response.get(
                "Topics",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return topics


@pytest.fixture(scope="session")
def topic_arn(
    topics,
):
    for topic in topics:
        arn = topic.get(
            "TopicArn"
        )

        if not arn:
            continue

        name = arn.rsplit(
            ":",
            1,
        )[-1]

        if name == EXPECTED_TOPIC_NAME:
            return arn

    pytest.fail(
        f"SNS topic not found: {EXPECTED_TOPIC_NAME}"
    )


@pytest.fixture(scope="session")
def topic_attributes(
    sns_client,
    topic_arn,
):
    response = sns_client.get_topic_attributes(
        TopicArn=topic_arn,
    )

    return response.get(
        "Attributes",
        {},
    )


@pytest.fixture(scope="session")
def topic_tags(
    sns_client,
    topic_arn,
):
    response = sns_client.list_tags_for_resource(
        ResourceArn=topic_arn,
    )

    return {
        tag["Key"]: tag["Value"]
        for tag in response.get(
            "Tags",
            [],
        )
    }


@pytest.fixture(scope="session")
def subscriptions(
    sns_client,
    topic_arn,
):
    subscriptions = []
    next_token = None

    while True:
        kwargs = {
            "TopicArn": topic_arn,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = sns_client.list_subscriptions_by_topic(
            **kwargs
        )

        subscriptions.extend(
            response.get(
                "Subscriptions",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return subscriptions


# ============================================================
# Topic
# ============================================================

def test_topic_exists(
    topic_arn,
):
    assert topic_arn


def test_topic_name(
    topic_arn,
):
    actual_name = topic_arn.rsplit(
        ":",
        1,
    )[-1]

    assert actual_name == EXPECTED_TOPIC_NAME


def test_topic_arn_format(
    topic_arn,
):
    assert topic_arn.startswith(
        f"arn:aws:sns:{AWS_REGION}:"
    )


# ============================================================
# FIFO
# ============================================================

def test_fifo_configuration(
    topic_attributes,
):
    actual_fifo = topic_attributes.get(
        "FifoTopic",
        "false",
    ).lower()

    expected_fifo = (
        "true"
        if SNS_FIFO_TOPIC
        else "false"
    )

    assert actual_fifo == expected_fifo


def test_fifo_name_suffix(
    topic_arn,
):
    topic_name = topic_arn.rsplit(
        ":",
        1,
    )[-1]

    if SNS_FIFO_TOPIC:
        assert topic_name.endswith(
            ".fifo"
        )
    else:
        assert not topic_name.endswith(
            ".fifo"
        )


def test_content_based_deduplication(
    topic_attributes,
):
    actual = topic_attributes.get(
        "ContentBasedDeduplication",
        "false",
    ).lower()

    if SNS_FIFO_TOPIC:
        expected = (
            "true"
            if SNS_CONTENT_BASED_DEDUPLICATION
            else "false"
        )

        assert actual == expected

    else:
        assert actual == "false"


# ============================================================
# Encryption
# ============================================================

def test_kms_configuration(
    topic_attributes,
):
    actual_kms = topic_attributes.get(
        "KmsMasterKeyId"
    )

    if SNS_KMS_MASTER_KEY_ID:
        assert (
            actual_kms
            == SNS_KMS_MASTER_KEY_ID
        )

    else:
        assert actual_kms in {
            None,
            "",
        }


# ============================================================
# Tags
# ============================================================

def test_project_tag(
    topic_tags,
):
    assert (
        topic_tags.get("Project")
        == PROJECT_NAME
    )


def test_environment_tag(
    topic_tags,
):
    assert (
        topic_tags.get("Environment")
        == ENVIRONMENT
    )


def test_component_tag(
    topic_tags,
):
    assert (
        topic_tags.get("Component")
        == "messaging"
    )


def test_service_tag(
    topic_tags,
):
    assert (
        topic_tags.get("Service")
        == "sns"
    )


# ============================================================
# Subscriptions
# ============================================================

def test_subscription_protocols(
    subscriptions,
):
    allowed_protocols = {
        "email",
        "email-json",
        "http",
        "https",
        "lambda",
        "sqs",
    }

    for subscription in subscriptions:
        protocol = subscription.get(
            "Protocol"
        )

        assert protocol in allowed_protocols


def test_subscription_endpoints_exist(
    subscriptions,
):
    for subscription in subscriptions:
        endpoint = subscription.get(
            "Endpoint"
        )

        assert endpoint


def test_subscription_arns_valid(
    subscriptions,
):
    for subscription in subscriptions:
        subscription_arn = subscription.get(
            "SubscriptionArn"
        )

        assert subscription_arn

        if subscription_arn != "PendingConfirmation":
            assert subscription_arn.startswith(
                "arn:aws:sns:"
            )


def test_subscription_owner_exists(
    subscriptions,
):
    for subscription in subscriptions:
        owner = subscription.get(
            "Owner"
        )

        assert owner


def test_subscription_counts_are_valid(
    topic_attributes,
):
    confirmed = int(
        topic_attributes.get(
            "SubscriptionsConfirmed",
            "0",
        )
    )

    pending = int(
        topic_attributes.get(
            "SubscriptionsPending",
            "0",
        )
    )

    deleted = int(
        topic_attributes.get(
            "SubscriptionsDeleted",
            "0",
        )
    )

    assert confirmed >= 0
    assert pending >= 0
    assert deleted >= 0


# ============================================================
# Runtime - Publish
# ============================================================

def test_publish_message(
    sns_client,
    topic_arn,
):
    kwargs = {
        "TopicArn": topic_arn,
        "Message": (
            "terraform sns pytest message"
        ),
    }

    if SNS_FIFO_TOPIC:
        kwargs["MessageGroupId"] = (
            "pytest"
        )

        if not SNS_CONTENT_BASED_DEDUPLICATION:
            kwargs[
                "MessageDeduplicationId"
            ] = (
                "pytest-message-001"
            )

    response = sns_client.publish(
        **kwargs
    )

    message_id = response.get(
        "MessageId"
    )

    assert message_id


# ============================================================
# Runtime - Publish Response
# ============================================================

def test_publish_response_metadata(
    sns_client,
    topic_arn,
):
    kwargs = {
        "TopicArn": topic_arn,
        "Message": (
            "terraform sns pytest "
            "metadata message"
        ),
    }

    if SNS_FIFO_TOPIC:
        kwargs["MessageGroupId"] = (
            "pytest-metadata"
        )

        if not SNS_CONTENT_BASED_DEDUPLICATION:
            kwargs[
                "MessageDeduplicationId"
            ] = (
                "pytest-message-002"
            )

    response = sns_client.publish(
        **kwargs
    )

    metadata = response.get(
        "ResponseMetadata",
        {},
    )

    status_code = metadata.get(
        "HTTPStatusCode"
    )

    assert status_code == 200