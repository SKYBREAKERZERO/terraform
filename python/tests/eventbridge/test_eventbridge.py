import json
import os
import uuid

import boto3
import pytest
from botocore.exceptions import ClientError


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
# Runtime Event
# ============================================================

EVENTBRIDGE_TEST_SOURCE = os.getenv(
    "EVENTBRIDGE_TEST_SOURCE",
    "pytest.eventbridge",
)

EVENTBRIDGE_TEST_DETAIL_TYPE = os.getenv(
    "EVENTBRIDGE_TEST_DETAIL_TYPE",
    "PytestEvent",
)


# ============================================================
# Expected Event Bus
# ============================================================

EXPECTED_EVENT_BUS_NAME = (
    (
        EVENTBRIDGE_EVENT_BUS_NAME
        if EVENTBRIDGE_EVENT_BUS_NAME
        else f"{PROJECT_NAME}-{ENVIRONMENT}-events"
    )
    if EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS
    else "default"
)

EXPECTED_EVENT_BUS_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Component": "messaging",
    "Service": "eventbridge",
}


# ============================================================
# Helpers
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
        pytest.fail(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        )

    assert isinstance(
        value,
        dict,
    ), (
        f"{variable_name} must contain "
        "a JSON object."
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
            return json.loads(
                value
            )

        except json.JSONDecodeError:
            return value

    return value


def expected_rule_name(
    logical_key,
    expected_rule,
):
    configured_name = expected_rule.get(
        "name"
    )

    if configured_name:
        return configured_name

    return (
        f"{PROJECT_NAME}-"
        f"{ENVIRONMENT}-"
        f"{logical_key}"
    )


def get_resource_tags(
    client,
    resource_arn,
):
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


def get_targets_for_rule(
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
            kwargs["NextToken"] = (
                next_token
            )

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
# Fixtures
# ============================================================

@pytest.fixture(scope="session")
def eventbridge_client():
    return boto3.client(
        "events",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


@pytest.fixture(scope="session")
def expected_rules():
    return parse_json_object(
        EVENTBRIDGE_RULES_JSON,
        "EVENTBRIDGE_RULES_JSON",
    )


@pytest.fixture(scope="session")
def expected_targets():
    return parse_json_object(
        EVENTBRIDGE_TARGETS_JSON,
        "EVENTBRIDGE_TARGETS_JSON",
    )


@pytest.fixture(scope="session")
def event_bus(
    eventbridge_client,
):
    try:
        response = (
            eventbridge_client
            .describe_event_bus(
                Name=EXPECTED_EVENT_BUS_NAME,
            )
        )

    except ClientError as error:
        pytest.fail(
            "EventBridge event bus "
            f"not found: "
            f"{EXPECTED_EVENT_BUS_NAME}: "
            f"{error}"
        )

    return response


@pytest.fixture(scope="session")
def event_bus_tags(
    eventbridge_client,
    event_bus,
):
    event_bus_arn = event_bus.get(
        "Arn"
    )

    if not event_bus_arn:
        return {}

    return get_resource_tags(
        eventbridge_client,
        event_bus_arn,
    )


@pytest.fixture(scope="session")
def rules(
    eventbridge_client,
):
    rules = []
    next_token = None

    while True:
        kwargs = {
            "EventBusName":
                EXPECTED_EVENT_BUS_NAME,
        }

        if next_token:
            kwargs["NextToken"] = (
                next_token
            )

        response = (
            eventbridge_client
            .list_rules(
                **kwargs
            )
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


@pytest.fixture(scope="session")
def rules_by_name(
    eventbridge_client,
    rules,
):
    result = {}

    for rule in rules:
        rule_name = rule.get(
            "Name"
        )

        if not rule_name:
            continue

        details = (
            eventbridge_client
            .describe_rule(
                Name=rule_name,
                EventBusName=(
                    EXPECTED_EVENT_BUS_NAME
                ),
            )
        )

        result[
            rule_name
        ] = details

    return result


@pytest.fixture(scope="session")
def targets_by_rule(
    eventbridge_client,
    rules_by_name,
):
    result = {}

    for rule_name in rules_by_name:
        result[
            rule_name
        ] = get_targets_for_rule(
            eventbridge_client,
            rule_name,
        )

    return result


# ============================================================
# Event Bus Tests
# ============================================================

def test_event_bus_exists(
    event_bus,
):
    assert event_bus


def test_event_bus_name(
    event_bus,
):
    assert (
        event_bus.get("Name")
        == EXPECTED_EVENT_BUS_NAME
    )


def test_event_bus_arn_exists(
    event_bus,
):
    event_bus_arn = event_bus.get(
        "Arn"
    )

    assert event_bus_arn


def test_event_bus_arn_format(
    event_bus,
):
    event_bus_arn = event_bus.get(
        "Arn"
    )

    assert event_bus_arn

    assert event_bus_arn.startswith(
        f"arn:aws:events:{AWS_REGION}:"
    )

    assert (
        f":event-bus/"
        f"{EXPECTED_EVENT_BUS_NAME}"
        in event_bus_arn
    )


@pytest.mark.parametrize(
    (
        "tag_name",
        "expected_value",
    ),
    list(
        EXPECTED_EVENT_BUS_TAGS.items()
    ),
)
def test_custom_event_bus_tags(
    event_bus_tags,
    tag_name,
    expected_value,
):
    if not EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS:
        pytest.skip(
            "Default EventBridge bus "
            "is not module-tagged."
        )

    assert (
        event_bus_tags.get(
            tag_name
        )
        == expected_value
    )


# ============================================================
# Rule Generic Tests
# ============================================================

def test_expected_rules_exist(
    expected_rules,
    rules_by_name,
):
    for (
        logical_key,
        expected_rule
    ) in expected_rules.items():

        rule_name = expected_rule_name(
            logical_key,
            expected_rule,
        )

        assert rule_name in rules_by_name, (
            f"Expected EventBridge rule "
            f"not found: {rule_name}"
        )


def test_rule_arns_exist(
    rules_by_name,
):
    for (
        rule_name,
        rule
    ) in rules_by_name.items():

        rule_arn = rule.get(
            "Arn"
        )

        assert rule_arn, (
            f"Rule ARN missing: "
            f"{rule_name}"
        )

        assert rule_arn.startswith(
            f"arn:aws:events:{AWS_REGION}:"
        )


def test_rule_states_are_valid(
    rules_by_name,
):
    valid_states = {
        "ENABLED",
        "DISABLED",
        (
            "ENABLED_WITH_ALL_CLOUDTRAIL_"
            "MANAGEMENT_EVENTS"
        ),
    }

    for (
        rule_name,
        rule
    ) in rules_by_name.items():

        state = rule.get(
            "State"
        )

        assert state in valid_states, (
            f"Invalid state for "
            f"{rule_name}: {state}"
        )


def test_rule_event_patterns_are_json(
    rules_by_name,
):
    for (
        rule_name,
        rule
    ) in rules_by_name.items():

        event_pattern = rule.get(
            "EventPattern"
        )

        assert event_pattern, (
            f"EventPattern missing: "
            f"{rule_name}"
        )

        parsed = normalize_json(
            event_pattern
        )

        assert isinstance(
            parsed,
            dict,
        ), (
            f"EventPattern is not "
            f"a JSON object: "
            f"{rule_name}"
        )


# ============================================================
# Expected Rule Tests
# ============================================================

def test_expected_rule_states(
    expected_rules,
    rules_by_name,
):
    for (
        logical_key,
        expected_rule
    ) in expected_rules.items():

        rule_name = expected_rule_name(
            logical_key,
            expected_rule,
        )

        if rule_name not in rules_by_name:
            continue

        expected_enabled = (
            expected_rule.get(
                "enabled",
                True,
            )
        )

        expected_state = (
            "ENABLED"
            if expected_enabled
            else "DISABLED"
        )

        actual_state = (
            rules_by_name[
                rule_name
            ].get(
                "State"
            )
        )

        assert (
            actual_state
            == expected_state
        )


def test_expected_rule_event_patterns(
    expected_rules,
    rules_by_name,
):
    for (
        logical_key,
        expected_rule
    ) in expected_rules.items():

        rule_name = expected_rule_name(
            logical_key,
            expected_rule,
        )

        if rule_name not in rules_by_name:
            continue

        expected_pattern = (
            normalize_json(
                expected_rule.get(
                    "event_pattern"
                )
            )
        )

        actual_pattern = (
            normalize_json(
                rules_by_name[
                    rule_name
                ].get(
                    "EventPattern"
                )
            )
        )

        assert (
            actual_pattern
            == expected_pattern
        )


# ============================================================
# Rule Tags
# ============================================================

def test_expected_rule_tags(
    eventbridge_client,
    expected_rules,
    rules_by_name,
):
    for (
        logical_key,
        expected_rule
    ) in expected_rules.items():

        rule_name = expected_rule_name(
            logical_key,
            expected_rule,
        )

        if rule_name not in rules_by_name:
            continue

        rule = rules_by_name[
            rule_name
        ]

        rule_arn = rule.get(
            "Arn"
        )

        assert rule_arn

        tags = get_resource_tags(
            eventbridge_client,
            rule_arn,
        )

        expected_tags = {
            "Project":
                PROJECT_NAME,

            "Environment":
                ENVIRONMENT,

            "Component":
                "messaging",

            "Service":
                "eventbridge",

            "RuleKey":
                logical_key,
        }

        expected_tags.update(
            expected_rule.get(
                "tags",
                {},
            )
        )

        for (
            tag_name,
            expected_value
        ) in expected_tags.items():

            assert (
                tags.get(
                    tag_name
                )
                == expected_value
            ), (
                f"Rule {rule_name} "
                f"tag {tag_name} "
                f"does not match."
            )


# ============================================================
# Target Generic Tests
# ============================================================

def test_target_ids_exist(
    targets_by_rule,
):
    for (
        rule_name,
        targets
    ) in targets_by_rule.items():

        for target in targets:
            target_id = target.get(
                "Id"
            )

            assert target_id, (
                f"Target ID missing "
                f"for rule: "
                f"{rule_name}"
            )


def test_target_arns_exist(
    targets_by_rule,
):
    for (
        rule_name,
        targets
    ) in targets_by_rule.items():

        for target in targets:
            target_arn = target.get(
                "Arn"
            )

            assert target_arn, (
                f"Target ARN missing "
                f"for rule: "
                f"{rule_name}"
            )


def test_target_input_exclusivity(
    targets_by_rule,
):
    for targets in (
        targets_by_rule.values()
    ):
        for target in targets:
            configured = [
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

            assert (
                len(configured)
                <= 1
            )


# ============================================================
# Target Retry Policy
# ============================================================

def test_target_retry_policies(
    targets_by_rule,
):
    for targets in (
        targets_by_rule.values()
    ):
        for target in targets:
            retry_policy = target.get(
                "RetryPolicy"
            )

            if not retry_policy:
                continue

            maximum_age = (
                retry_policy.get(
                    "MaximumEventAgeInSeconds"
                )
            )

            maximum_attempts = (
                retry_policy.get(
                    "MaximumRetryAttempts"
                )
            )

            assert maximum_age is not None
            assert (
                60
                <= int(maximum_age)
                <= 86400
            )

            assert (
                maximum_attempts
                is not None
            )

            assert (
                0
                <= int(maximum_attempts)
                <= 185
            )


# ============================================================
# Target DLQ
# ============================================================

def test_target_dead_letter_configs(
    targets_by_rule,
):
    for targets in (
        targets_by_rule.values()
    ):
        for target in targets:
            dead_letter_config = (
                target.get(
                    "DeadLetterConfig"
                )
            )

            if not dead_letter_config:
                continue

            dlq_arn = (
                dead_letter_config.get(
                    "Arn"
                )
            )

            assert dlq_arn

            assert (
                ":sqs:"
                in dlq_arn
            )


# ============================================================
# Expected Targets
# ============================================================

def test_expected_targets_exist(
    expected_rules,
    expected_targets,
    targets_by_rule,
):
    for (
        target_key,
        expected_target
    ) in expected_targets.items():

        rule_key = expected_target.get(
            "rule_key"
        )

        assert rule_key, (
            f"Expected target "
            f"{target_key} "
            "has no rule_key."
        )

        assert rule_key in expected_rules, (
            f"Target {target_key} "
            f"references unknown rule: "
            f"{rule_key}"
        )

        rule_name = expected_rule_name(
            rule_key,
            expected_rules[
                rule_key
            ],
        )

        actual_targets = (
            targets_by_rule.get(
                rule_name,
                [],
            )
        )

        expected_target_id = (
            expected_target.get(
                "target_id"
            )
            or target_key
        )

        actual_target = next(
            (
                target
                for target in actual_targets
                if target.get("Id")
                == expected_target_id
            ),
            None,
        )

        assert actual_target, (
            f"Expected target "
            f"not found: "
            f"{expected_target_id}"
        )


def test_expected_target_arns(
    expected_rules,
    expected_targets,
    targets_by_rule,
):
    for (
        target_key,
        expected_target
    ) in expected_targets.items():

        expected_arn = (
            expected_target.get(
                "arn"
            )
        )

        if not expected_arn:
            continue

        rule_key = expected_target.get(
            "rule_key"
        )

        if rule_key not in expected_rules:
            continue

        rule_name = expected_rule_name(
            rule_key,
            expected_rules[
                rule_key
            ],
        )

        expected_target_id = (
            expected_target.get(
                "target_id"
            )
            or target_key
        )

        actual_target = next(
            (
                target
                for target in (
                    targets_by_rule.get(
                        rule_name,
                        [],
                    )
                )
                if target.get("Id")
                == expected_target_id
            ),
            None,
        )

        assert actual_target

        assert (
            actual_target.get(
                "Arn"
            )
            == expected_arn
        )


# ============================================================
# Runtime - PutEvents
# ============================================================

def test_put_event(
    eventbridge_client,
):
    test_id = str(
        uuid.uuid4()
    )

    detail = {
        "test_id": test_id,
        "project": PROJECT_NAME,
        "environment": ENVIRONMENT,
        "source": "pytest",
    }

    response = (
        eventbridge_client
        .put_events(
            Entries=[
                {
                    "Source":
                        EVENTBRIDGE_TEST_SOURCE,

                    "DetailType":
                        EVENTBRIDGE_TEST_DETAIL_TYPE,

                    "Detail":
                        json.dumps(
                            detail
                        ),

                    "EventBusName":
                        EXPECTED_EVENT_BUS_NAME,
                }
            ]
        )
    )

    assert (
        response.get(
            "FailedEntryCount",
            0,
        )
        == 0
    )

    entries = response.get(
        "Entries",
        [],
    )

    assert len(entries) == 1

    entry = entries[0]

    assert not entry.get(
        "ErrorCode"
    )

    assert not entry.get(
        "ErrorMessage"
    )

    assert entry.get(
        "EventId"
    )


# ============================================================
# Runtime Response Metadata
# ============================================================

def test_put_event_response_metadata(
    eventbridge_client,
):
    response = (
        eventbridge_client
        .put_events(
            Entries=[
                {
                    "Source":
                        EVENTBRIDGE_TEST_SOURCE,

                    "DetailType":
                        EVENTBRIDGE_TEST_DETAIL_TYPE,

                    "Detail":
                        json.dumps(
                            {
                                "test":
                                    "response-metadata"
                            }
                        ),

                    "EventBusName":
                        EXPECTED_EVENT_BUS_NAME,
                }
            ]
        )
    )

    metadata = response.get(
        "ResponseMetadata",
        {},
    )

    assert (
        metadata.get(
            "HTTPStatusCode"
        )
        == 200
    )