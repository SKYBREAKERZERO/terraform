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

SQS_QUEUE_NAME = os.getenv(
    "SQS_QUEUE_NAME",
)

SQS_FIFO_QUEUE = os.getenv(
    "SQS_FIFO_QUEUE",
    "false",
).lower() == "true"


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
    response = client.get_queue_url(
        QueueName=queue_name,
    )

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


def print_separator():
    print("=" * 70)


def print_queue(
    title,
    queue,
):
    attributes = queue["attributes"]

    print_separator()
    print(title)
    print_separator()

    print(
        f"Name:                  "
        f"{queue['name']}"
    )

    print(
        f"URL:                   "
        f"{queue['url']}"
    )

    print(
        f"ARN:                   "
        f"{attributes.get('QueueArn', '')}"
    )

    print(
        f"FIFO Queue:            "
        f"{attributes.get('FifoQueue', 'false')}"
    )

    print(
        f"Content Dedup:         "
        f"{attributes.get('ContentBasedDeduplication', 'false')}"
    )

    print(
        f"Visibility Timeout:    "
        f"{attributes.get('VisibilityTimeout', '')}"
    )

    print(
        f"Message Retention:     "
        f"{attributes.get('MessageRetentionPeriod', '')}"
    )

    print(
        f"Receive Wait Time:     "
        f"{attributes.get('ReceiveMessageWaitTimeSeconds', '')}"
    )

    print(
        f"Delay Seconds:         "
        f"{attributes.get('DelaySeconds', '')}"
    )

    print(
        f"Max Message Size:      "
        f"{attributes.get('MaximumMessageSize', '')}"
    )

    print(
        f"Messages Available:    "
        f"{attributes.get('ApproximateNumberOfMessages', '0')}"
    )

    print(
        f"Messages In Flight:    "
        f"{attributes.get('ApproximateNumberOfMessagesNotVisible', '0')}"
    )

    print(
        f"Messages Delayed:      "
        f"{attributes.get('ApproximateNumberOfMessagesDelayed', '0')}"
    )

    kms_key_id = attributes.get(
        "KmsMasterKeyId"
    )

    print(
        f"KMS Key:               "
        f"{kms_key_id or 'disabled'}"
    )

    redrive_policy = attributes.get(
        "RedrivePolicy"
    )

    print(
        f"Redrive Policy:        "
        f"{redrive_policy or 'disabled'}"
    )

def print_tags(
        title,
    tags,
):
    print()

    print_separator()
    print(title)
    print_separator()

    if not tags:
        print("No tags found.")
        return

    for key in sorted(tags):
        print(
            f"{key}={tags[key]}"
        )

def run():
    client = create_sqs_client()

    main_queue = get_queue_info(
        client,
        EXPECTED_QUEUE_NAME,
    )

    print_queue(
        "Main Queue",
        main_queue,
    )

    print_tags(
        "Main Queue Tags",
        main_queue["tags"],
    )

    print()

    try:
        dlq = get_queue_info(
            client,
            EXPECTED_DLQ_NAME,
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
            print_separator()
            print("SQS DEAD LETTER QUEUE")
            print_separator()
            print(
                "DLQ not configured."
            )
            return

        raise

    print_queue(
        "Dead Letter Queue",
        dlq,
    )

    print_tags(
        "Dead Letter Queue Tags",
        dlq["tags"],
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