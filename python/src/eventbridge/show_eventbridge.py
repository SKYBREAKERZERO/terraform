import json
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


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

EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS = os.getenv(
    "EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS",
    "true",
).lower() == "true"

EVENTBRIDGE_EVENT_BUS_NAME = os.getenv(
    "EVENTBRIDGE_EVENT_BUS_NAME",
)


# ============================================================
# Expected Event Bus
# ============================================================

EXPECTED_EVENT_BUS_NAME = (
    EVENTBRIDGE_EVENT_BUS_NAME
    if EVENTBRIDGE_EVENT_BUS_NAME
    else (
        f"{PROJECT_NAME}-{ENVIRONMENT}-events"
        if EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS
        else "default"
    )
)


# ============================================================
# Client
# ============================================================

def create_eventbridge_client():
    return boto3.client(
        "events",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# Event Bus
# ============================================================

def get_event_bus(
    client,
):
    response = client.describe_event_bus(
        Name=EXPECTED_EVENT_BUS_NAME,
    )

    return {
        "Name": response.get(
            "Name",
            EXPECTED_EVENT_BUS_NAME,
        ),
        "Arn": response.get(
            "Arn"
        ),
        "Policy": response.get(
            "Policy"
        ),
    }


def get_resource_tags(
    client,
    resource_arn,
):
    if not resource_arn:
        return {}

    response = client.list_tags_for_resource(
        ResourceARN=resource_arn,
    )

    return {
        tag["Key"]: tag["Value"]
        for tag in response.get(
            "Tags",
            [],
        )
    }


# ============================================================
# Rules
# ============================================================

def get_rules(
    client,
):
    rules = []
    next_token = None

    while True:
        kwargs = {
            "EventBusName": EXPECTED_EVENT_BUS_NAME,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.list_rules(
            **kwargs
        )

        rules.extend(
            response.get(
                "Rules",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return rules


def get_rule_details(
    client,
    rule_name,
):
    response = client.describe_rule(
        Name=rule_name,
        EventBusName=EXPECTED_EVENT_BUS_NAME,
    )

    return response


# ============================================================
# Targets
# ============================================================

def get_targets(
    client,
    rule_name,
):
    targets = []
    next_token = None

    while True:
        kwargs = {
            "Rule": rule_name,
            "EventBusName": EXPECTED_EVENT_BUS_NAME,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.list_targets_by_rule(
            **kwargs
        )

        targets.extend(
            response.get(
                "Targets",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return targets


# ============================================================
# Formatting
# ============================================================

def print_separator(
    character="=",
):
    print(
        character * 70
    )


def format_json(
    value,
):
    if not value:
        return ""

    if isinstance(
        value,
        str,
    ):
        try:
            value = json.loads(
                value
            )

        except (
            json.JSONDecodeError,
            TypeError,
        ):
            return value

    return json.dumps(
        value,
        indent=2,
        sort_keys=True,
    )


# ============================================================
# Event Bus Output
# ============================================================

def print_event_bus(
    event_bus,
    tags,
):
    print_separator()
    print("EVENTBRIDGE EVENT BUS")
    print_separator()

    print(
        f"Name:             "
        f"{event_bus.get('Name', '')}"
    )

    print(
        f"ARN:              "
        f"{event_bus.get('Arn') or ''}"
    )

    print(
        f"Custom Bus:       "
        f"{str(EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS).lower()}"
    )

    print()

    print("Tags:")

    if not tags:
        print(
            "  No tags configured."
        )

    else:
        for key in sorted(tags):
            print(
                f"  {key}={tags[key]}"
            )


# ============================================================
# Rule Output
# ============================================================

def print_rule(
    client,
    rule,
):
    rule_name = rule.get(
        "Name"
    )

    details = get_rule_details(
        client,
        rule_name,
    )

    rule_arn = details.get(
        "Arn"
    )

    tags = get_resource_tags(
        client,
        rule_arn,
    )

    targets = get_targets(
        client,
        rule_name,
    )

    print()
    print_separator()
    print("RULE")
    print_separator()

    print(
        f"Name:             "
        f"{rule_name}"
    )

    print(
        f"ARN:              "
        f"{rule_arn or ''}"
    )

    print(
        f"State:            "
        f"{details.get('State', '')}"
    )

    print(
        f"Description:      "
        f"{details.get('Description') or ''}"
    )

    print(
        f"Event Bus:        "
        f"{details.get('EventBusName', EXPECTED_EVENT_BUS_NAME)}"
    )

    print()

    print("Event Pattern:")

    event_pattern = details.get(
        "EventPattern"
    )

    if event_pattern:
        print(
            format_json(
                event_pattern
            )
        )

    else:
        print(
            "  No event pattern configured."
        )

    print()

    print("Tags:")

    if not tags:
        print(
            "  No tags configured."
        )

    else:
        for key in sorted(tags):
            print(
                f"  {key}={tags[key]}"
            )

    print_targets(
        targets
    )


# ============================================================
# Target Output
# ============================================================

def print_targets(
    targets,
):
    print()

    print_separator("-")
    print("TARGETS")
    print_separator("-")

    if not targets:
        print(
            "No targets configured."
        )
        return

    for target in targets:
        print(
            f"Target ID:        "
            f"{target.get('Id', '')}"
        )

        print(
            f"Target ARN:       "
            f"{target.get('Arn', '')}"
        )

        print(
            f"Role ARN:         "
            f"{target.get('RoleArn') or 'none'}"
        )

        input_value = target.get(
            "Input"
        )

        input_path = target.get(
            "InputPath"
        )

        input_transformer = target.get(
            "InputTransformer"
        )

        retry_policy = target.get(
            "RetryPolicy"
        )

        dead_letter_config = target.get(
            "DeadLetterConfig"
        )

        if input_value:
            print(
                "Input:"
            )

            print(
                format_json(
                    input_value
                )
            )

        if input_path:
            print(
                f"Input Path:       "
                f"{input_path}"
            )

        if input_transformer:
            print(
                "Input Transformer:"
            )

            print(
                format_json(
                    input_transformer
                )
            )

        if retry_policy:
            print(
                "Retry Policy:"
            )

            print(
                format_json(
                    retry_policy
                )
            )

        if dead_letter_config:
            print(
                "Dead Letter Config:"
            )

            print(
                format_json(
                    dead_letter_config
                )
            )

        print_separator("-")


# ============================================================
# Run
# ============================================================

def run():
    client = create_eventbridge_client()

    event_bus = get_event_bus(
        client
    )

    event_bus_tags = get_resource_tags(
        client,
        event_bus.get(
            "Arn"
        ),
    )

    rules = get_rules(
        client
    )

    print_event_bus(
        event_bus,
        event_bus_tags,
    )

    print()

    print_separator()
    print("RULE SUMMARY")
    print_separator()

    print(
        f"Rules:            "
        f"{len(rules)}"
    )

    if not rules:
        print(
            "No EventBridge rules configured."
        )
        return

    for rule in rules:
        print_rule(
            client,
            rule,
        )


# ============================================================
# Main
# ============================================================

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

    except (
        TypeError,
        ValueError,
    ) as error:
        print(
            "[ERROR] Configuration error: "
            f"{error}"
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
    sys.exit(
        main()
    )