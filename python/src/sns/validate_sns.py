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

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Component": "messaging",
    "Service": "sns",
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


def create_sns_client():
    return boto3.client(
        "sns",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


def get_topics(client):
    topics = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.list_topics(
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


def get_topic_arn(client):
    topics = get_topics(
        client
    )

    for topic in topics:
        topic_arn = topic.get(
            "TopicArn"
        )

        if not topic_arn:
            continue

        topic_name = topic_arn.rsplit(
            ":",
            1,
        )[-1]

        if topic_name == EXPECTED_TOPIC_NAME:
            return topic_arn

    return None


def get_topic_attributes(
    client,
    topic_arn,
):
    response = client.get_topic_attributes(
        TopicArn=topic_arn,
    )

    return response.get(
        "Attributes",
        {},
    )


def get_topic_tags(
    client,
    topic_arn,
):
    response = client.list_tags_for_resource(
        ResourceArn=topic_arn,
    )

    return {
        tag["Key"]: tag["Value"]
        for tag in response.get(
            "Tags",
            [],
        )
    }


def get_subscriptions(
    client,
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

        response = client.list_subscriptions_by_topic(
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


def validate_topic_arn(
    topic_arn,
):
    if not topic_arn:
        fail_check(
            f"SNS topic not found: {EXPECTED_TOPIC_NAME}"
        )
        return

    pass_check(
        f"SNS topic exists: {EXPECTED_TOPIC_NAME}"
    )

    actual_name = topic_arn.rsplit(
        ":",
        1,
    )[-1]

    if actual_name == EXPECTED_TOPIC_NAME:
        pass_check(
            f"SNS topic name is correct: {actual_name}"
        )
    else:
        fail_check(
            "Unexpected SNS topic name: "
            f"{actual_name}"
        )


def validate_attributes(
    attributes,
):
    expected_fifo = (
        "true"
        if SNS_FIFO_TOPIC
        else "false"
    )

    actual_fifo = attributes.get(
        "FifoTopic",
        "false",
    ).lower()

    if actual_fifo == expected_fifo:
        pass_check(
            f"FIFO configuration is {expected_fifo}"
        )
    else:
        fail_check(
            "Unexpected FIFO configuration: "
            f"{actual_fifo}"
        )

    expected_dedup = (
        "true"
        if SNS_CONTENT_BASED_DEDUPLICATION
        else "false"
    )

    actual_dedup = attributes.get(
        "ContentBasedDeduplication",
        "false",
    ).lower()

    if SNS_FIFO_TOPIC:
        if actual_dedup == expected_dedup:
            pass_check(
                "Content-based deduplication "
                f"is {expected_dedup}"
            )
        else:
            fail_check(
                "Unexpected content-based "
                "deduplication configuration: "
                f"{actual_dedup}"
            )
    else:
        if actual_dedup == "false":
            pass_check(
                "Content-based deduplication "
                "is disabled for Standard topic"
            )
        else:
            fail_check(
                "Content-based deduplication "
                "should be disabled for Standard topic"
            )

    actual_kms = attributes.get(
        "KmsMasterKeyId"
    )

    if SNS_KMS_MASTER_KEY_ID:
        if actual_kms == SNS_KMS_MASTER_KEY_ID:
            pass_check(
                "SNS KMS key matches expected value"
            )
        else:
            fail_check(
                "Unexpected SNS KMS key: "
                f"{actual_kms}"
            )
    else:
        if actual_kms:
            warn_check(
                "SNS topic uses KMS encryption "
                f"but no expected KMS key was configured: {actual_kms}"
            )
        else:
            pass_check(
                "SNS topic has no custom KMS key"
            )

    confirmed = attributes.get(
        "SubscriptionsConfirmed",
        "0",
    )

    pending = attributes.get(
        "SubscriptionsPending",
        "0",
    )

    deleted = attributes.get(
        "SubscriptionsDeleted",
        "0",
    )

    pass_check(
        f"Confirmed subscriptions reported: {confirmed}"
    )

    if pending == "0":
        pass_check(
            "No pending subscriptions"
        )
    else:
        warn_check(
            f"Pending subscriptions: {pending}"
        )

    if deleted == "0":
        pass_check(
            "No deleted subscriptions reported"
        )
    else:
        warn_check(
            f"Deleted subscriptions reported: {deleted}"
        )

def validate_subscriptions(
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

    if not subscriptions:
        warn_check(
            "No SNS subscriptions configured"
        )
        return

    pass_check(
        f"SNS has {len(subscriptions)} subscription(s)"
    )

    for subscription in subscriptions:
        protocol = subscription.get(
            "Protocol"
        )

        endpoint = subscription.get(
            "Endpoint"
        )

        subscription_arn = subscription.get(
            "SubscriptionArn"
        )

        if protocol in allowed_protocols:
            pass_check(
                f"Supported subscription protocol: {protocol}"
            )
        else:
            fail_check(
                f"Unsupported subscription protocol: {protocol}"
            )

        if endpoint:
            pass_check(
                f"Subscription endpoint exists: {endpoint}"
            )
        else:
            fail_check(
                f"Subscription endpoint missing for {protocol}"
            )

        if subscription_arn:
            if subscription_arn == "PendingConfirmation":
                warn_check(
                    f"Subscription is pending confirmation: {endpoint}"
                )
            else:
                pass_check(
                    f"Subscription ARN exists: {subscription_arn}"
                )
        else:
            warn_check(
                f"Subscription ARN missing for {endpoint}"
            )


def validate_tags(
    tags,
):
    if not tags:
        fail_check(
            "SNS topic has no tags"
        )
        return

    pass_check(
        "SNS topic has tags"
    )

    for key, expected_value in EXPECTED_TAGS.items():
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"Tag {key}={expected_value}"
            )
        elif actual_value is None:
            fail_check(
                f"Required tag missing: {key}"
            )
        else:
            fail_check(
                f"Tag {key} expected "
                f"{expected_value}, got {actual_value}"
            )


def print_summary():
    print()
    print("=" * 70)
    print("SNS VALIDATION SUMMARY")
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
    client = create_sns_client()

    topic_arn = get_topic_arn(
        client
    )

    validate_topic_arn(
        topic_arn
    )

    if not topic_arn:
        return

    attributes = get_topic_attributes(
        client,
        topic_arn,
    )

    subscriptions = get_subscriptions(
        client,
        topic_arn,
    )

    tags = get_topic_tags(
        client,
        topic_arn,
    )

    validate_attributes(
        attributes
    )

    validate_subscriptions(
        subscriptions
    )

    validate_tags(
        tags
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

    except RuntimeError as error:
        fail_check(
            str(error)
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