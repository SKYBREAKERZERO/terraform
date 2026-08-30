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

EVENTBRIDGE_RULES_JSON = os.getenv(
    "EVENTBRIDGE_RULES_JSON",
    "{}",
)

EVENTBRIDGE_TARGETS_JSON = os.getenv(
    "EVENTBRIDGE_TARGETS_JSON",
    "{}",
)


# ============================================================
# Expected Configuration
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

EXPECTED_EVENT_BUS_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Component": "messaging",
    "Service": "eventbridge",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(message):
    global PASS_COUNT

    PASS_COUNT += 1
    print(
        f"[PASS] {message}"
    )


def warn_check(message):
    global WARN_COUNT

    WARN_COUNT += 1
    print(
        f"[WARN] {message}"
    )


def fail_check(message):
    global FAIL_COUNT

    FAIL_COUNT += 1
    print(
        f"[FAIL] {message}"
    )


# ============================================================
# Configuration Parsing
# ============================================================

def parse_json_object(
    raw_value,
    variable_name,
):
    try:
        value = json.loads(
            raw_value
        )

    except json.JSONDecodeError as error:
        raise ValueError(
            f"{variable_name} must contain valid JSON: "
            f"{error}"
        ) from error

    if not isinstance(
        value,
        dict,
    ):
        raise ValueError(
            f"{variable_name} must contain a JSON object."
        )

    return value


def normalize_json(
    value,
):
    if value is None:
        return None

    if isinstance(
        value,
        str,
    ):
        try:
            value = json.loads(
                value
            )

        except json.JSONDecodeError:
            return value

    return value


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
    try:
        return client.describe_event_bus(
            Name=EXPECTED_EVENT_BUS_NAME,
        )

    except ClientError as error:
        error_code = (
            error.response
            .get("Error", {})
            .get("Code", "")
        )

        if error_code in {
            "ResourceNotFoundException",
            "ResourceNotFound",
        }:
            return None

        raise


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
            "EventBusName":
                EXPECTED_EVENT_BUS_NAME,
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
    return client.describe_rule(
        Name=rule_name,
        EventBusName=EXPECTED_EVENT_BUS_NAME,
    )


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
            "EventBusName":
                EXPECTED_EVENT_BUS_NAME,
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
# Event Bus Validation
# ============================================================

def validate_event_bus(
    client,
    event_bus,
):
    if not event_bus:
        fail_check(
            "EventBridge event bus not found: "
            f"{EXPECTED_EVENT_BUS_NAME}"
        )
        return False

    pass_check(
        "EventBridge event bus exists: "
        f"{EXPECTED_EVENT_BUS_NAME}"
    )

    actual_name = event_bus.get(
        "Name"
    )

    if actual_name == EXPECTED_EVENT_BUS_NAME:
        pass_check(
            f"Event bus name is correct: "
            f"{actual_name}"
        )
    else:
        fail_check(
            "Unexpected event bus name: "
            f"{actual_name}"
        )

    event_bus_arn = event_bus.get(
        "Arn"
    )

    if event_bus_arn:
        pass_check(
            f"Event bus ARN exists: "
            f"{event_bus_arn}"
        )
    else:
        fail_check(
            "Event bus ARN is missing."
        )

    if (
        EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS
        and event_bus_arn
    ):
        tags = get_resource_tags(
            client,
            event_bus_arn,
        )

        validate_tags(
            tags,
            EXPECTED_EVENT_BUS_TAGS,
            "Event bus",
        )

    else:
        pass_check(
            "Default event bus does not require "
            "module-managed tags."
        )

    return True


# ============================================================
# Generic Tags
# ============================================================

def validate_tags(
    tags,
    expected_tags,
    resource_type,
):
    if not tags:
        fail_check(
            f"{resource_type} has no tags."
        )
        return

    pass_check(
        f"{resource_type} has tags."
    )

    for key, expected_value in (
        expected_tags.items()
    ):
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"{resource_type} tag "
                f"{key}={expected_value}"
            )

        elif actual_value is None:
            fail_check(
                f"{resource_type} required tag "
                f"is missing: {key}"
            )

        else:
            fail_check(
                f"{resource_type} tag {key} "
                f"expected {expected_value}, "
                f"got {actual_value}"
            )


# ============================================================
# Rule Validation
# ============================================================

def validate_rule(
    client,
    logical_key,
    rule,
    expected_rule=None,
):
    rule_name = rule.get(
        "Name"
    )

    if not rule_name:
        fail_check(
            f"Rule {logical_key} has no name."
        )
        return

    pass_check(
        f"Rule exists: {rule_name}"
    )

    details = get_rule_details(
        client,
        rule_name,
    )

    rule_arn = details.get(
        "Arn"
    )

    if rule_arn:
        pass_check(
            f"Rule ARN exists: {rule_arn}"
        )
    else:
        fail_check(
            f"Rule ARN is missing: {rule_name}"
        )

    state = details.get(
        "State"
    )

    if state in {
        "ENABLED",
        "DISABLED",
        "ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS",
    }:
        pass_check(
            f"Rule state is valid: "
            f"{rule_name}={state}"
        )
    else:
        fail_check(
            f"Rule has invalid state: "
            f"{rule_name}={state}"
        )

    event_pattern_raw = details.get(
        "EventPattern"
    )

    if not event_pattern_raw:
        fail_check(
            f"Rule event pattern is missing: "
            f"{rule_name}"
        )

    else:
        try:
            json.loads(
                event_pattern_raw
            )

            pass_check(
                f"Rule event pattern is valid JSON: "
                f"{rule_name}"
            )

        except json.JSONDecodeError:
            fail_check(
                f"Rule event pattern is invalid JSON: "
                f"{rule_name}"
            )

    if rule_arn:
        tags = get_resource_tags(
            client,
            rule_arn,
        )

        expected_tags = {
            "Project": PROJECT_NAME,
            "Environment": ENVIRONMENT,
            "Component": "messaging",
            "Service": "eventbridge",
            "RuleKey": logical_key,
        }

        validate_tags(
            tags,
            expected_tags,
            f"Rule {rule_name}",
        )

    if expected_rule:
        validate_expected_rule(
            details,
            logical_key,
            expected_rule,
        )


def validate_expected_rule(
    details,
    logical_key,
    expected_rule,
):
    expected_name = expected_rule.get(
        "name"
    )

    if not expected_name:
        expected_name = (
            f"{PROJECT_NAME}-"
            f"{ENVIRONMENT}-"
            f"{logical_key}"
        )

    actual_name = details.get(
        "Name"
    )

    if actual_name == expected_name:
        pass_check(
            f"Rule name matches expected value: "
            f"{actual_name}"
        )
    else:
        fail_check(
            f"Rule name expected {expected_name}, "
            f"got {actual_name}"
        )

    expected_enabled = expected_rule.get(
        "enabled",
        True,
    )

    expected_state = (
        "ENABLED"
        if expected_enabled
        else "DISABLED"
    )

    actual_state = details.get(
        "State"
    )

    if actual_state == expected_state:
        pass_check(
            f"Rule state matches expected value: "
            f"{actual_state}"
        )
    else:
        fail_check(
            f"Rule state expected "
            f"{expected_state}, "
            f"got {actual_state}"
        )

    expected_pattern = normalize_json(
        expected_rule.get(
            "event_pattern"
        )
    )

    actual_pattern = normalize_json(
        details.get(
            "EventPattern"
        )
    )

    if expected_pattern is not None:
        if actual_pattern == expected_pattern:
            pass_check(
                f"Rule event pattern matches: "
                f"{actual_name}"
            )
        else:
            fail_check(
                f"Rule event pattern does not match: "
                f"{actual_name}"
            )


# ============================================================
# Target Validation
# ============================================================

def validate_target(
    target,
    rule_name,
):
    target_id = target.get(
        "Id"
    )

    if target_id:
        pass_check(
            f"Target ID exists: "
            f"{rule_name}/{target_id}"
        )
    else:
        fail_check(
            f"Target ID missing for rule: "
            f"{rule_name}"
        )

    target_arn = target.get(
        "Arn"
    )

    if target_arn:
        pass_check(
            f"Target ARN exists: "
            f"{target_arn}"
        )
    else:
        fail_check(
            f"Target ARN missing: "
            f"{rule_name}/{target_id}"
        )

    validate_target_input(
        target,
        rule_name,
        target_id,
    )

    validate_retry_policy(
        target,
        rule_name,
        target_id,
    )

    validate_dead_letter_config(
        target,
        rule_name,
        target_id,
    )


def validate_target_input(
    target,
    rule_name,
    target_id,
):
    configured_inputs = [
        value
        for value in (
            target.get(
                "Input"
            ),
            target.get(
                "InputPath"
            ),
            target.get(
                "InputTransformer"
            ),
        )
        if value is not None
    ]

    if len(configured_inputs) <= 1:
        pass_check(
            "Target input configuration is valid: "
            f"{rule_name}/{target_id}"
        )
    else:
        fail_check(
            "Target Input, InputPath and "
            "InputTransformer are mutually exclusive: "
            f"{rule_name}/{target_id}"
        )

    transformer = target.get(
        "InputTransformer"
    )

    if transformer:
        template = transformer.get(
            "InputTemplate"
        )

        if template:
            pass_check(
                "InputTransformer template exists: "
                f"{rule_name}/{target_id}"
            )
        else:
            fail_check(
                "InputTransformer template is missing: "
                f"{rule_name}/{target_id}"
            )


def validate_retry_policy(
    target,
    rule_name,
    target_id,
):
    retry_policy = target.get(
        "RetryPolicy"
    )

    if not retry_policy:
        warn_check(
            "Target has no RetryPolicy: "
            f"{rule_name}/{target_id}"
        )
        return

    maximum_age = retry_policy.get(
        "MaximumEventAgeInSeconds"
    )

    maximum_attempts = retry_policy.get(
        "MaximumRetryAttempts"
    )

    if (
        maximum_age is not None
        and 60 <= int(maximum_age) <= 86400
    ):
        pass_check(
            "MaximumEventAgeInSeconds is valid: "
            f"{maximum_age}"
        )
    else:
        fail_check(
            "Invalid MaximumEventAgeInSeconds: "
            f"{maximum_age}"
        )

    if (
        maximum_attempts is not None
        and 0 <= int(maximum_attempts) <= 185
    ):
        pass_check(
            "MaximumRetryAttempts is valid: "
            f"{maximum_attempts}"
        )
    else:
        fail_check(
            "Invalid MaximumRetryAttempts: "
            f"{maximum_attempts}"
        )


def validate_dead_letter_config(
    target,
    rule_name,
    target_id,
):
    dead_letter_config = target.get(
        "DeadLetterConfig"
    )

    if not dead_letter_config:
        pass_check(
            "Target DLQ is not configured: "
            f"{rule_name}/{target_id}"
        )
        return

    dlq_arn = dead_letter_config.get(
        "Arn"
    )

    if dlq_arn:
        pass_check(
            f"Target DLQ ARN exists: "
            f"{dlq_arn}"
        )
    else:
        fail_check(
            "Target DeadLetterConfig exists "
            "without ARN: "
            f"{rule_name}/{target_id}"
        )


# ============================================================
# Expected Target Validation
# ============================================================

def validate_expected_targets(
    rules_by_key,
    expected_targets,
):
    if not expected_targets:
        return

    for (
        target_key,
        expected_target
    ) in expected_targets.items():

        rule_key = expected_target.get(
            "rule_key"
        )

        if not rule_key:
            fail_check(
                f"Expected target {target_key} "
                "has no rule_key."
            )
            continue

        rule_data = rules_by_key.get(
            rule_key
        )

        if not rule_data:
            fail_check(
                f"Expected target {target_key} "
                f"references missing rule: "
                f"{rule_key}"
            )
            continue

        expected_target_id = (
            expected_target.get(
                "target_id"
            )
            or target_key
        )

        targets = rule_data[
            "targets"
        ]

        actual_target = next(
            (
                target
                for target in targets
                if target.get("Id")
                == expected_target_id
            ),
            None,
        )

        if not actual_target:
            fail_check(
                f"Expected target not found: "
                f"{expected_target_id}"
            )
            continue

        pass_check(
            f"Expected target exists: "
            f"{expected_target_id}"
        )

        expected_arn = expected_target.get(
            "arn"
        )

        if expected_arn:
            actual_arn = actual_target.get(
                "Arn"
            )

            if actual_arn == expected_arn:
                pass_check(
                    f"Target ARN matches: "
                    f"{expected_target_id}"
                )
            else:
                fail_check(
                    f"Target ARN expected "
                    f"{expected_arn}, "
                    f"got {actual_arn}"
                )


# ============================================================
# Summary
# ============================================================

def print_summary():
    print()
    print(
        "=" * 70
    )
    print(
        "EVENTBRIDGE VALIDATION SUMMARY"
    )
    print(
        "=" * 70
    )

    print(
        f"PASS: {PASS_COUNT}"
    )

    print(
        f"WARN: {WARN_COUNT}"
    )

    print(
        f"FAIL: {FAIL_COUNT}"
    )


# ============================================================
# Run
# ============================================================

def run():
    expected_rules = parse_json_object(
        EVENTBRIDGE_RULES_JSON,
        "EVENTBRIDGE_RULES_JSON",
    )

    expected_targets = parse_json_object(
        EVENTBRIDGE_TARGETS_JSON,
        "EVENTBRIDGE_TARGETS_JSON",
    )

    client = create_eventbridge_client()

    event_bus = get_event_bus(
        client
    )

    if not validate_event_bus(
        client,
        event_bus,
    ):
        return

    rules = get_rules(
        client
    )

    if not rules:
        if expected_rules:
            fail_check(
                "No EventBridge rules found, "
                "but rules were expected."
            )
        else:
            warn_check(
                "No EventBridge rules configured."
            )

        return

    pass_check(
        f"EventBridge has "
        f"{len(rules)} rule(s)."
    )

    rules_by_key = {}

    expected_rule_names = {}

    for (
        logical_key,
        expected_rule
    ) in expected_rules.items():

        expected_rule_names[
            (
                expected_rule.get("name")
                or (
                    f"{PROJECT_NAME}-"
                    f"{ENVIRONMENT}-"
                    f"{logical_key}"
                )
            )
        ] = logical_key

    for rule in rules:
        rule_name = rule.get(
            "Name"
        )

        logical_key = (
            expected_rule_names.get(
                rule_name
            )
        )

        if logical_key is None:
            logical_key = (
                rule_name
                .removeprefix(
                    f"{PROJECT_NAME}-"
                    f"{ENVIRONMENT}-"
                )
            )

        expected_rule = expected_rules.get(
            logical_key
        )

        validate_rule(
            client,
            logical_key,
            rule,
            expected_rule,
        )

        targets = get_targets(
            client,
            rule_name,
        )

        if not targets:
            warn_check(
                f"Rule has no targets: "
                f"{rule_name}"
            )

        else:
            pass_check(
                f"Rule {rule_name} has "
                f"{len(targets)} target(s)."
            )

            for target in targets:
                validate_target(
                    target,
                    rule_name,
                )

        rules_by_key[
            logical_key
        ] = {
            "rule": rule,
            "targets": targets,
        }

    for logical_key in expected_rules:
        if logical_key not in rules_by_key:
            fail_check(
                f"Expected EventBridge rule "
                f"not found: {logical_key}"
            )

    validate_expected_targets(
        rules_by_key,
        expected_targets,
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

        fail_check(
            "AWS API error: "
            f"{error_code}: "
            f"{error_message}"
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