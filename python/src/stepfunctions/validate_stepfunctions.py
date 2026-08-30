import json
import os
import re
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

STEPFUNCTIONS_STATE_MACHINE_NAME = os.getenv(
    "STEPFUNCTIONS_STATE_MACHINE_NAME",
)

STEPFUNCTIONS_STATE_MACHINE_TYPE = os.getenv(
    "STEPFUNCTIONS_STATE_MACHINE_TYPE",
    "STANDARD",
).upper()

STEPFUNCTIONS_ROLE_ARN = os.getenv(
    "STEPFUNCTIONS_ROLE_ARN",
)

STEPFUNCTIONS_DEFINITION_JSON = os.getenv(
    "STEPFUNCTIONS_DEFINITION_JSON",
)

STEPFUNCTIONS_LOGGING_ENABLED = os.getenv(
    "STEPFUNCTIONS_LOGGING_ENABLED",
    "false",
).lower() == "true"

STEPFUNCTIONS_LOG_DESTINATION = os.getenv(
    "STEPFUNCTIONS_LOG_DESTINATION",
)

STEPFUNCTIONS_LOG_LEVEL = os.getenv(
    "STEPFUNCTIONS_LOG_LEVEL",
    "ALL",
).upper()

STEPFUNCTIONS_INCLUDE_EXECUTION_DATA = os.getenv(
    "STEPFUNCTIONS_INCLUDE_EXECUTION_DATA",
    "true",
).lower() == "true"

STEPFUNCTIONS_TRACING_ENABLED = os.getenv(
    "STEPFUNCTIONS_TRACING_ENABLED",
    "false",
).lower() == "true"


# ============================================================
# Expected Configuration
# ============================================================

EXPECTED_STATE_MACHINE_NAME = (
    STEPFUNCTIONS_STATE_MACHINE_NAME
    if STEPFUNCTIONS_STATE_MACHINE_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-workflow"
)

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_STATE_MACHINE_NAME,
    "Component": "workflow",
    "Service": "stepfunctions",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(
    message,
):
    global PASS_COUNT

    PASS_COUNT += 1

    print(
        f"[PASS] {message}"
    )


def warn_check(
    message,
):
    global WARN_COUNT

    WARN_COUNT += 1

    print(
        f"[WARN] {message}"
    )


def fail_check(
    message,
):
    global FAIL_COUNT

    FAIL_COUNT += 1

    print(
        f"[FAIL] {message}"
    )


# ============================================================
# Client
# ============================================================

def create_stepfunctions_client():
    return boto3.client(
        "stepfunctions",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# State Machine Discovery
# ============================================================

def get_state_machines(
    client,
):
    state_machines = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["nextToken"] = next_token

        response = client.list_state_machines(
            **kwargs
        )

        state_machines.extend(
            response.get(
                "stateMachines",
                [],
            )
        )

        next_token = response.get(
            "nextToken"
        )

        if not next_token:
            break

    return state_machines


def get_state_machine_arn(
    client,
):
    state_machines = get_state_machines(
        client
    )

    for state_machine in state_machines:
        name = state_machine.get(
            "name"
        )

        if name != EXPECTED_STATE_MACHINE_NAME:
            continue

        return state_machine.get(
            "stateMachineArn"
        )

    return None


def get_state_machine_details(
    client,
    state_machine_arn,
):
    return client.describe_state_machine(
        stateMachineArn=state_machine_arn,
    )


def get_state_machine_tags(
    client,
    state_machine_arn,
):
    response = client.list_tags_for_resource(
        resourceArn=state_machine_arn,
    )

    return {
        tag["key"]: tag["value"]
        for tag in response.get(
            "tags",
            [],
        )
    }


# ============================================================
# JSON Helpers
# ============================================================

def parse_json(
    value,
):
    if isinstance(
        value,
        dict,
    ):
        return value

    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "State machine definition is not a JSON string."
        )

    return json.loads(
        value
    )


def normalize_json(
    value,
):
    parsed = parse_json(
        value
    )

    return json.dumps(
        parsed,
        sort_keys=True,
        separators=(
            ",",
            ":",
        ),
    )


# ============================================================
# State Machine Identity
# ============================================================

def validate_state_machine_exists(
    state_machine_arn,
):
    if not state_machine_arn:
        fail_check(
            "Step Functions state machine not found: "
            f"{EXPECTED_STATE_MACHINE_NAME}"
        )

        return False

    pass_check(
        "Step Functions state machine exists: "
        f"{EXPECTED_STATE_MACHINE_NAME}"
    )

    return True


def validate_identity(
    state_machine_arn,
    details,
):
    actual_name = details.get(
        "name"
    )

    if actual_name == EXPECTED_STATE_MACHINE_NAME:
        pass_check(
            f"State machine name is correct: "
            f"{actual_name}"
        )
    else:
        fail_check(
            "Unexpected state machine name: "
            f"{actual_name}"
        )

    actual_arn = details.get(
        "stateMachineArn"
    )

    if actual_arn == state_machine_arn:
        pass_check(
            "State machine ARN matches discovered ARN."
        )
    else:
        fail_check(
            "State machine ARN does not match "
            "discovered ARN."
        )

    if actual_arn:
        expected_prefix = (
            f"arn:aws:states:"
            f"{AWS_REGION}:"
        )

        if actual_arn.startswith(
            expected_prefix
        ):
            pass_check(
                "State machine ARN format is valid."
            )
        else:
            fail_check(
                "Unexpected state machine ARN format: "
                f"{actual_arn}"
            )
    else:
        fail_check(
            "State machine ARN is missing."
        )


# ============================================================
# Status / Type
# ============================================================

def validate_status(
    details,
):
    status = details.get(
        "status"
    )

    if status == "ACTIVE":
        pass_check(
            "State machine status is ACTIVE."
        )
    else:
        fail_check(
            "State machine status expected ACTIVE, "
            f"got {status}"
        )


def validate_state_machine_type(
    details,
):
    actual_type = details.get(
        "type"
    )

    if actual_type == STEPFUNCTIONS_STATE_MACHINE_TYPE:
        pass_check(
            "State machine type matches expected value: "
            f"{actual_type}"
        )
    else:
        fail_check(
            "State machine type expected "
            f"{STEPFUNCTIONS_STATE_MACHINE_TYPE}, "
            f"got {actual_type}"
        )


# ============================================================
# IAM Role
# ============================================================

def validate_role(
    details,
):
    actual_role_arn = details.get(
        "roleArn"
    )

    if not actual_role_arn:
        fail_check(
            "State machine execution role ARN is missing."
        )

        return

    role_pattern = re.compile(
        r"^arn:[^:]+:iam::[0-9]{12}:role/.+$"
    )

    if role_pattern.match(
        actual_role_arn
    ):
        pass_check(
            "State machine execution role ARN "
            "format is valid."
        )
    else:
        fail_check(
            "Invalid state machine execution "
            f"role ARN: {actual_role_arn}"
        )

    if STEPFUNCTIONS_ROLE_ARN:
        if actual_role_arn == STEPFUNCTIONS_ROLE_ARN:
            pass_check(
                "State machine execution role "
                "matches expected ARN."
            )
        else:
            fail_check(
                "State machine execution role "
                f"expected {STEPFUNCTIONS_ROLE_ARN}, "
                f"got {actual_role_arn}"
            )


# ============================================================
# ASL Definition
# ============================================================

def validate_definition(
    details,
):
    definition_raw = details.get(
        "definition"
    )

    if not definition_raw:
        fail_check(
            "State machine definition is missing."
        )

        return

    try:
        definition = parse_json(
            definition_raw
        )

    except (
        json.JSONDecodeError,
        TypeError,
        ValueError,
    ) as error:
        fail_check(
            "State machine definition is invalid JSON: "
            f"{error}"
        )

        return

    if not isinstance(
        definition,
        dict,
    ):
        fail_check(
            "State machine definition must be "
            "a JSON object."
        )

        return

    pass_check(
        "State machine definition is valid JSON."
    )

    start_at = definition.get(
        "StartAt"
    )

    if (
        isinstance(start_at, str)
        and start_at
    ):
        pass_check(
            f"ASL StartAt exists: {start_at}"
        )
    else:
        fail_check(
            "ASL StartAt is missing or invalid."
        )

    states = definition.get(
        "States"
    )

    if (
        isinstance(states, dict)
        and states
    ):
        pass_check(
            f"ASL States contains "
            f"{len(states)} state(s)."
        )
    else:
        fail_check(
            "ASL States is missing or empty."
        )

        return

    if (
        start_at
        and start_at in states
    ):
        pass_check(
            "ASL StartAt references an existing state."
        )
    else:
        fail_check(
            "ASL StartAt does not reference "
            "an existing state."
        )

    validate_states(
        states
    )

    if STEPFUNCTIONS_DEFINITION_JSON:
        validate_expected_definition(
            definition
        )


def validate_states(
    states,
):
    valid_types = {
        "Task",
        "Pass",
        "Choice",
        "Wait",
        "Succeed",
        "Fail",
        "Parallel",
        "Map",
    }

    for (
        state_name,
        state_definition
    ) in states.items():

        if not isinstance(
            state_definition,
            dict,
        ):
            fail_check(
                f"State {state_name} "
                "definition is not an object."
            )

            continue

        state_type = state_definition.get(
            "Type"
        )

        if state_type in valid_types:
            pass_check(
                f"State {state_name} "
                f"type is valid: {state_type}"
            )
        else:
            fail_check(
                f"State {state_name} "
                f"has invalid type: {state_type}"
            )


def validate_expected_definition(
    actual_definition,
):
    try:
        expected_definition = parse_json(
            STEPFUNCTIONS_DEFINITION_JSON
        )

    except (
        json.JSONDecodeError,
        TypeError,
        ValueError,
    ) as error:
        fail_check(
            "STEPFUNCTIONS_DEFINITION_JSON "
            f"is invalid: {error}"
        )

        return

    actual_normalized = normalize_json(
        actual_definition
    )

    expected_normalized = normalize_json(
        expected_definition
    )

    if (
        actual_normalized
        == expected_normalized
    ):
        pass_check(
            "State machine definition matches "
            "expected ASL."
        )
    else:
        fail_check(
            "State machine definition does not "
            "match expected ASL."
        )


# ============================================================
# Logging
# ============================================================

def validate_logging(
    details,
):
    logging_configuration = details.get(
        "loggingConfiguration",
        {},
    )

    actual_level = logging_configuration.get(
        "level",
        "OFF",
    )

    actual_include_data = (
        logging_configuration.get(
            "includeExecutionData",
            False,
        )
    )

    destinations = logging_configuration.get(
        "destinations",
        [],
    )

    if not STEPFUNCTIONS_LOGGING_ENABLED:
        if (
            actual_level == "OFF"
            or not destinations
        ):
            pass_check(
                "Step Functions logging is disabled."
            )
        else:
            fail_check(
                "Logging is configured although "
                "STEPFUNCTIONS_LOGGING_ENABLED=false."
            )

        return

    if actual_level == STEPFUNCTIONS_LOG_LEVEL:
        pass_check(
            "Logging level matches expected value: "
            f"{actual_level}"
        )
    else:
        fail_check(
            "Logging level expected "
            f"{STEPFUNCTIONS_LOG_LEVEL}, "
            f"got {actual_level}"
        )

    if (
        actual_include_data
        == STEPFUNCTIONS_INCLUDE_EXECUTION_DATA
    ):
        pass_check(
            "Logging includeExecutionData "
            "matches expected value."
        )
    else:
        fail_check(
            "Logging includeExecutionData does "
            "not match expected value."
        )

    if not destinations:
        fail_check(
            "Logging is enabled but no "
            "log destination exists."
        )

        return

    pass_check(
        f"Logging has "
        f"{len(destinations)} destination(s)."
    )

    if STEPFUNCTIONS_LOG_DESTINATION:
        actual_destinations = []

        for destination in destinations:
            log_group = destination.get(
                "cloudWatchLogsLogGroup",
                {},
            )

            log_group_arn = log_group.get(
                "logGroupArn"
            )

            if log_group_arn:
                actual_destinations.append(
                    log_group_arn
                )

        if (
            STEPFUNCTIONS_LOG_DESTINATION
            in actual_destinations
        ):
            pass_check(
                "Logging destination matches "
                "expected ARN."
            )
        else:
            fail_check(
                "Expected logging destination "
                "was not found."
            )


# ============================================================
# X-Ray
# ============================================================

def validate_tracing(
    details,
):
    tracing_configuration = details.get(
        "tracingConfiguration",
        {},
    )

    actual_enabled = tracing_configuration.get(
        "enabled",
        False,
    )

    if (
        actual_enabled
        == STEPFUNCTIONS_TRACING_ENABLED
    ):
        pass_check(
            "X-Ray tracing matches expected value: "
            f"{str(actual_enabled).lower()}"
        )
    else:
        fail_check(
            "X-Ray tracing expected "
            f"{str(STEPFUNCTIONS_TRACING_ENABLED).lower()}, "
            f"got {str(actual_enabled).lower()}"
        )


# ============================================================
# Tags
# ============================================================

def validate_tags(
    tags,
):
    if not tags:
        fail_check(
            "State machine has no tags."
        )

        return

    pass_check(
        "State machine has tags."
    )

    for (
        key,
        expected_value
    ) in EXPECTED_TAGS.items():

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
                f"{expected_value}, "
                f"got {actual_value}"
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
        "STEP FUNCTIONS VALIDATION SUMMARY"
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
    client = create_stepfunctions_client()

    state_machine_arn = get_state_machine_arn(
        client
    )

    if not validate_state_machine_exists(
        state_machine_arn
    ):
        return

    details = get_state_machine_details(
        client,
        state_machine_arn,
    )

    tags = get_state_machine_tags(
        client,
        state_machine_arn,
    )

    validate_identity(
        state_machine_arn,
        details,
    )

    validate_status(
        details
    )

    validate_state_machine_type(
        details
    )

    validate_role(
        details
    )

    validate_definition(
        details
    )

    validate_logging(
        details
    )

    validate_tracing(
        details
    )

    validate_tags(
        tags
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