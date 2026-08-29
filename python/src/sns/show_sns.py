import os

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

SNS_FIFO_TOPIC = os.getenv(
    "SNS_FIFO_TOPIC",
    "false",
).lower() == "true"

BASE_TOPIC_NAME = (
    f"{PROJECT_NAME}-{ENVIRONMENT}-alerts"
)

EXPECTED_TOPIC_NAME = (
    f"{BASE_TOPIC_NAME}.fifo"
    if SNS_FIFO_TOPIC
    else BASE_TOPIC_NAME
)


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


def get_topic_arn(
    client,
):
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

    raise RuntimeError(
        f"SNS topic not found: {EXPECTED_TOPIC_NAME}"
    )


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


def print_separator():
    print("=" * 70)


def print_topic(
    topic_arn,
    attributes,
):
    print_separator()
    print("SNS TOPIC")
    print_separator()

    print(
        f"Name:             "
        f"{EXPECTED_TOPIC_NAME}"
    )

    print(
        f"ARN:              "
        f"{topic_arn}"
    )

    print(
        f"Display Name:     "
        f"{attributes.get('DisplayName', '')}"
    )

    print(
        f"Owner:            "
        f"{attributes.get('Owner', '')}"
    )

    print(
        f"Subscriptions:    "
        f"{attributes.get('SubscriptionsConfirmed', '0')}"
    )

    print(
        f"Pending:          "
        f"{attributes.get('SubscriptionsPending', '0')}"
    )

    print(
        f"Deleted:          "
        f"{attributes.get('SubscriptionsDeleted', '0')}"
    )

    print(
        f"FIFO Topic:       "
        f"{attributes.get('FifoTopic', 'false')}"
    )

    print(
        "Content Dedup:    "
        f"{attributes.get('ContentBasedDeduplication', 'false')}"
    )

    kms_key_id = attributes.get(
        "KmsMasterKeyId"
    )

    print(
        f"KMS Key:          "
        f"{kms_key_id or 'disabled'}"
    )


def print_subscriptions(
    subscriptions,
):
    print()

    print_separator()
    print("SUBSCRIPTIONS")
    print_separator()

    if not subscriptions:
        print(
            "No subscriptions configured."
        )
        return

    for subscription in subscriptions:
        print(
            f"Protocol:         "
            f"{subscription.get('Protocol')}"
        )

        print(
            f"Endpoint:         "
            f"{subscription.get('Endpoint')}"
        )

        print(
            f"Subscription ARN: "
            f"{subscription.get('SubscriptionArn')}"
        )

        print(
            f"Owner:            "
            f"{subscription.get('Owner')}"
        )

        print("-" * 70)


def print_tags(
    tags,
):
    print()

    print_separator()
    print("TAGS")
    print_separator()

    if not tags:
        print(
            "No tags configured."
        )
        return

    for key in sorted(tags):
        print(
            f"{key}={tags[key]}"
        )


def run():
    client = create_sns_client()

    topic_arn = get_topic_arn(
        client
    )

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

    print_topic(
        topic_arn,
        attributes,
    )

    print_subscriptions(
        subscriptions
    )

    print_tags(
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

        print(
            "[ERROR] AWS API error: "
            f"{error_code}: {error_message}"
        )

        return 1

    except BotoCoreError as error:
        print(
            "[ERROR] AWS SDK error: "
            f"{error}"
        )

        return 1

    except RuntimeError as error:
        print(
            f"[ERROR] {error}"
        )

        return 1

    except KeyboardInterrupt:
        print()
        print(
            "[INFO] Interrupted by user."
        )

        return 130

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )