import json
import os
import re
import time
import uuid

import boto3
import pytest
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

STEPFUNCTIONS_EXECUTION_INPUT_JSON = os.getenv(
    "STEPFUNCTIONS_EXECUTION_INPUT_JSON",
    json.dumps(
        {
            "order_id": "pytest-order-001",
            "source": "pytest",
        }
    ),
)

STEPFUNCTIONS_EXPECTED_OUTPUT_JSON = os.getenv(
    "STEPFUNCTIONS_EXPECTED_OUTPUT_JSON",
)

STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS = int(
    os.getenv(
        "STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS",
        "30",
    )
)

STEPFUNCTIONS_POLL_INTERVAL_SECONDS = float(
    os.getenv(
        "STEPFUNCTIONS_POLL_INTERVAL_SECONDS",
        "0.5",
    )
)


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
# Helpers
# ============================================================

def parse_json_object(
    value,
    variable_name,
):
    try:
        parsed = json.loads(
            value
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        )

    if not isinstance(
        parsed,
        dict,
    ):
        pytest.fail(
            f"{variable_name} must contain "
            "a JSON object."
        )

    return parsed


def normalize_json(
    value,
):
    if isinstance(
        value,
        str,
    ):
        value = json.loads(
            value
        )

    return json.dumps(
        value,
        sort_keys=True,
        separators=(
            ",",
            ":",
        ),
    )


def expected_execution_input():
    return parse_json_object(
        STEPFUNCTIONS_EXECUTION_INPUT_JSON,
        "STEPFUNCTIONS_EXECUTION_INPUT_JSON",
    )


# ============================================================
# Client Fixture
# ============================================================

@pytest.fixture(
    scope="session"
)
def stepfunctions_client():
    return boto3.client(
        "stepfunctions",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# State Machine Discovery
# ============================================================

@pytest.fixture(
    scope="session"
)
def state_machines(
    stepfunctions_client,
):
    machines = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["nextToken"] = next_token

        response = (
            stepfunctions_client
            .list_state_machines(
                **kwargs
            )
        )

        machines.extend(
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

    return machines


@pytest.fixture(
    scope="session"
)
def state_machine_summary(
    state_machines,
):
    for machine in state_machines:
        if (
            machine.get("name")
            == EXPECTED_STATE_MACHINE_NAME
        ):
            return machine

    pytest.fail(
        "Step Functions state machine "
        "was not found: "
        f"{EXPECTED_STATE_MACHINE_NAME}"
    )


@pytest.fixture(
    scope="session"
)
def state_machine_arn(
    state_machine_summary,
):
    arn = state_machine_summary.get(
        "stateMachineArn"
    )

    assert arn, (
        "State machine ARN is missing."
    )

    return arn


@pytest.fixture(
    scope="session"
)
def state_machine_details(
    stepfunctions_client,
    state_machine_arn,
):
    return (
        stepfunctions_client
        .describe_state_machine(
            stateMachineArn=(
                state_machine_arn
            ),
        )
    )


@pytest.fixture(
    scope="session"
)
def state_machine_tags(
    stepfunctions_client,
    state_machine_arn,
):
    response = (
        stepfunctions_client
        .list_tags_for_resource(
            resourceArn=(
                state_machine_arn
            ),
        )
    )

    return {
        tag["key"]: tag["value"]
        for tag in response.get(
            "tags",
            [],
        )
    }


@pytest.fixture(
    scope="session"
)
def state_machine_definition(
    state_machine_details,
):
    raw_definition = (
        state_machine_details.get(
            "definition"
        )
    )

    assert raw_definition, (
        "State machine definition "
        "is missing."
    )

    try:
        definition = json.loads(
            raw_definition
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "State machine definition "
            f"is invalid JSON: {error}"
        )

    assert isinstance(
        definition,
        dict,
    )

    return definition


# ============================================================
# Basic API Tests
# ============================================================

def test_stepfunctions_api_available(
    stepfunctions_client,
):
    response = (
        stepfunctions_client
        .list_state_machines(
            maxResults=1,
        )
    )

    metadata = response.get(
        "ResponseMetadata",
        {},
    )

    assert (
        metadata.get("HTTPStatusCode")
        == 200
    )


def test_state_machine_exists(
    state_machine_summary,
):
    assert (
        state_machine_summary["name"]
        == EXPECTED_STATE_MACHINE_NAME
    )


# ============================================================
# Identity
# ============================================================

def test_state_machine_name(
    state_machine_details,
):
    assert (
        state_machine_details.get(
            "name"
        )
        == EXPECTED_STATE_MACHINE_NAME
    )


def test_state_machine_arn(
    state_machine_arn,
):
    pattern = re.compile(
        r"^arn:[^:]+:states:"
        r"[^:]+:"
        r"[0-9]{12}:"
        r"stateMachine:"
        r".+$"
    )

    assert pattern.match(
        state_machine_arn
    ), (
        "Invalid Step Functions "
        f"state machine ARN: "
        f"{state_machine_arn}"
    )


def test_state_machine_region(
    state_machine_arn,
):
    arn_parts = (
        state_machine_arn.split(
            ":",
            6,
        )
    )

    assert len(
        arn_parts
    ) >= 7

    assert (
        arn_parts[3]
        == AWS_REGION
    )


# ============================================================
# Status / Type
# ============================================================

def test_state_machine_status(
    state_machine_details,
):
    assert (
        state_machine_details.get(
            "status"
        )
        == "ACTIVE"
    )


def test_state_machine_type(
    state_machine_details,
):
    assert (
        state_machine_details.get(
            "type"
        )
        == STEPFUNCTIONS_STATE_MACHINE_TYPE
    )


# ============================================================
# IAM Role
# ============================================================

def test_execution_role_exists(
    state_machine_details,
):
    role_arn = (
        state_machine_details.get(
            "roleArn"
        )
    )

    assert role_arn, (
        "State machine roleArn "
        "is missing."
    )


def test_execution_role_arn_format(
    state_machine_details,
):
    role_arn = (
        state_machine_details.get(
            "roleArn"
        )
    )

    pattern = re.compile(
        r"^arn:[^:]+:"
        r"iam::"
        r"[0-9]{12}:"
        r"role/.+$"
    )

    assert pattern.match(
        role_arn
    ), (
        "Invalid Step Functions "
        f"execution role ARN: "
        f"{role_arn}"
    )


def test_execution_role_matches_expected(
    state_machine_details,
):
    if not STEPFUNCTIONS_ROLE_ARN:
        pytest.skip(
            "STEPFUNCTIONS_ROLE_ARN "
            "not configured."
        )

    assert (
        state_machine_details.get(
            "roleArn"
        )
        == STEPFUNCTIONS_ROLE_ARN
    )


# ============================================================
# ASL Definition
# ============================================================

def test_definition_is_json_object(
    state_machine_definition,
):
    assert isinstance(
        state_machine_definition,
        dict,
    )


def test_definition_has_start_at(
    state_machine_definition,
):
    start_at = (
        state_machine_definition.get(
            "StartAt"
        )
    )

    assert isinstance(
        start_at,
        str,
    )

    assert start_at


def test_definition_has_states(
    state_machine_definition,
):
    states = (
        state_machine_definition.get(
            "States"
        )
    )

    assert isinstance(
        states,
        dict,
    )

    assert states


def test_start_at_references_existing_state(
    state_machine_definition,
):
    start_at = (
        state_machine_definition[
            "StartAt"
        ]
    )

    states = (
        state_machine_definition[
            "States"
        ]
    )

    assert start_at in states


@pytest.mark.parametrize(
    "valid_state_type",
    [
        "Task",
        "Pass",
        "Choice",
        "Wait",
        "Succeed",
        "Fail",
        "Parallel",
        "Map",
    ],
)
def test_valid_asl_state_type_reference(
    valid_state_type,
):
    assert valid_state_type in {
        "Task",
        "Pass",
        "Choice",
        "Wait",
        "Succeed",
        "Fail",
        "Parallel",
        "Map",
    }


def test_all_states_have_valid_type(
    state_machine_definition,
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

    states = (
        state_machine_definition[
            "States"
        ]
    )

    for (
        state_name,
        state_definition
    ) in states.items():

        assert isinstance(
            state_definition,
            dict,
        ), (
            f"State {state_name} "
            "must be an object."
        )

        state_type = (
            state_definition.get(
                "Type"
            )
        )

        assert (
            state_type
            in valid_types
        ), (
            f"State {state_name} "
            f"has invalid Type: "
            f"{state_type}"
        )


def test_definition_matches_expected(
    state_machine_definition,
):
    if not STEPFUNCTIONS_DEFINITION_JSON:
        pytest.skip(
            "STEPFUNCTIONS_DEFINITION_JSON "
            "not configured."
        )

    try:
        expected_definition = json.loads(
            STEPFUNCTIONS_DEFINITION_JSON
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "STEPFUNCTIONS_DEFINITION_JSON "
            f"is invalid: {error}"
        )

    assert (
        normalize_json(
            state_machine_definition
        )
        == normalize_json(
            expected_definition
        )
    )


# ============================================================
# Logging
# ============================================================

def test_logging_configuration(
    state_machine_details,
):
    config = (
        state_machine_details.get(
            "loggingConfiguration",
            {},
        )
    )

    level = config.get(
        "level",
        "OFF",
    )

    destinations = config.get(
        "destinations",
        [],
    )

    if not STEPFUNCTIONS_LOGGING_ENABLED:
        assert (
            level == "OFF"
            or not destinations
        )

        return

    assert (
        level
        == STEPFUNCTIONS_LOG_LEVEL
    )

    assert (
        config.get(
            "includeExecutionData",
            False,
        )
        == STEPFUNCTIONS_INCLUDE_EXECUTION_DATA
    )

    assert destinations, (
        "Logging is enabled but "
        "no log destination exists."
    )


def test_logging_destination(
    state_machine_details,
):
    if (
        not STEPFUNCTIONS_LOGGING_ENABLED
        or not STEPFUNCTIONS_LOG_DESTINATION
    ):
        pytest.skip(
            "Logging destination "
            "validation not enabled."
        )

    config = (
        state_machine_details.get(
            "loggingConfiguration",
            {},
        )
    )

    destinations = config.get(
        "destinations",
        [],
    )

    actual_arns = []

    for destination in destinations:
        log_group = destination.get(
            "cloudWatchLogsLogGroup",
            {},
        )

        arn = log_group.get(
            "logGroupArn"
        )

        if arn:
            actual_arns.append(
                arn
            )

    assert (
        STEPFUNCTIONS_LOG_DESTINATION
        in actual_arns
    )


# ============================================================
# X-Ray
# ============================================================

def test_tracing_configuration(
    state_machine_details,
):
    tracing = (
        state_machine_details.get(
            "tracingConfiguration",
            {},
        )
    )

    assert (
        tracing.get(
            "enabled",
            False,
        )
        == STEPFUNCTIONS_TRACING_ENABLED
    )


# ============================================================
# Tags
# ============================================================

def test_state_machine_has_tags(
    state_machine_tags,
):
    assert state_machine_tags


@pytest.mark.parametrize(
    (
        "tag_key",
        "expected_value",
    ),
    EXPECTED_TAGS.items(),
)
def test_required_tags(
    state_machine_tags,
    tag_key,
    expected_value,
):
    assert (
        state_machine_tags.get(
            tag_key
        )
        == expected_value
    )


# ============================================================
# Runtime Helpers
# ============================================================

def wait_for_standard_execution(
    client,
    execution_arn,
):
    deadline = (
        time.monotonic()
        + STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS
    )

    last_response = None

    while time.monotonic() < deadline:
        last_response = (
            client.describe_execution(
                executionArn=(
                    execution_arn
                ),
            )
        )

        status = last_response.get(
            "status"
        )

        if status in {
            "SUCCEEDED",
            "FAILED",
            "TIMED_OUT",
            "ABORTED",
        }:
            return last_response

        time.sleep(
            STEPFUNCTIONS_POLL_INTERVAL_SECONDS
        )

    pytest.fail(
        "Step Functions execution "
        "did not finish within "
        f"{STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS} "
        "seconds. "
        f"Last response: {last_response}"
    )


# ============================================================
# Runtime - STANDARD
# ============================================================

@pytest.fixture(
    scope="session"
)
def standard_execution_result(
    stepfunctions_client,
    state_machine_arn,
):
    if (
        STEPFUNCTIONS_STATE_MACHINE_TYPE
        != "STANDARD"
    ):
        pytest.skip(
            "STANDARD execution test "
            "not applicable to EXPRESS."
        )

    execution_name = (
        "pytest-"
        + uuid.uuid4().hex[:24]
    )

    input_data = (
        expected_execution_input()
    )

    response = (
        stepfunctions_client
        .start_execution(
            stateMachineArn=(
                state_machine_arn
            ),
            name=execution_name,
            input=json.dumps(
                input_data
            ),
        )
    )

    execution_arn = response.get(
        "executionArn"
    )

    assert execution_arn, (
        "start_execution did not "
        "return executionArn."
    )

    result = wait_for_standard_execution(
        stepfunctions_client,
        execution_arn,
    )

    return {
        "start_response": response,
        "execution": result,
        "input": input_data,
    }


def test_standard_execution_started(
    standard_execution_result,
):
    response = (
        standard_execution_result[
            "start_response"
        ]
    )

    assert response.get(
        "executionArn"
    )

    assert response.get(
        "startDate"
    )


def test_standard_execution_succeeded(
    standard_execution_result,
):
    execution = (
        standard_execution_result[
            "execution"
        ]
    )

    assert (
        execution.get(
            "status"
        )
        == "SUCCEEDED"
    ), (
        "Execution did not succeed. "
        f"Status={execution.get('status')} "
        f"Error={execution.get('error')} "
        f"Cause={execution.get('cause')}"
    )


def test_standard_execution_output_is_json(
    standard_execution_result,
):
    execution = (
        standard_execution_result[
            "execution"
        ]
    )

    output = execution.get(
        "output"
    )

    assert output is not None, (
        "Execution output is missing."
    )

    try:
        parsed_output = json.loads(
            output
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "Execution output is "
            f"not valid JSON: {error}"
        )

    assert parsed_output is not None


def test_standard_execution_output_matches_expected(
    standard_execution_result,
):
    if not STEPFUNCTIONS_EXPECTED_OUTPUT_JSON:
        pytest.skip(
            "STEPFUNCTIONS_EXPECTED_OUTPUT_JSON "
            "not configured."
        )

    execution = (
        standard_execution_result[
            "execution"
        ]
    )

    actual_output = execution.get(
        "output"
    )

    assert actual_output is not None

    try:
        expected_output = json.loads(
            STEPFUNCTIONS_EXPECTED_OUTPUT_JSON
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "STEPFUNCTIONS_EXPECTED_OUTPUT_JSON "
            f"is invalid: {error}"
        )

    assert (
        normalize_json(
            actual_output
        )
        == normalize_json(
            expected_output
        )
    )


# ============================================================
# Runtime - EXPRESS
# ============================================================

@pytest.fixture(
    scope="session"
)
def express_execution_result(
    stepfunctions_client,
    state_machine_arn,
):
    if (
        STEPFUNCTIONS_STATE_MACHINE_TYPE
        != "EXPRESS"
    ):
        pytest.skip(
            "EXPRESS execution test "
            "not applicable to STANDARD."
        )

    execution_name = (
        "pytest-"
        + uuid.uuid4().hex[:24]
    )

    input_data = (
        expected_execution_input()
    )

    try:
        response = (
            stepfunctions_client
            .start_sync_execution(
                stateMachineArn=(
                    state_machine_arn
                ),
                name=execution_name,
                input=json.dumps(
                    input_data
                ),
            )
        )

    except ClientError as error:
        pytest.fail(
            "EXPRESS StartSyncExecution "
            f"failed: {error}"
        )

    except BotoCoreError as error:
        pytest.fail(
            "EXPRESS SDK call failed: "
            f"{error}"
        )

    return {
        "response": response,
        "input": input_data,
    }


def test_express_execution_succeeded(
    express_execution_result,
):
    response = (
        express_execution_result[
            "response"
        ]
    )

    assert (
        response.get(
            "status"
        )
        == "SUCCEEDED"
    ), (
        "EXPRESS execution failed. "
        f"Status={response.get('status')} "
        f"Error={response.get('error')} "
        f"Cause={response.get('cause')}"
    )


def test_express_execution_output_is_json(
    express_execution_result,
):
    response = (
        express_execution_result[
            "response"
        ]
    )

    output = response.get(
        "output"
    )

    assert output is not None

    try:
        parsed_output = json.loads(
            output
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "EXPRESS execution output "
            f"is invalid JSON: {error}"
        )

    assert parsed_output is not None


def test_express_execution_output_matches_expected(
    express_execution_result,
):
    if not STEPFUNCTIONS_EXPECTED_OUTPUT_JSON:
        pytest.skip(
            "STEPFUNCTIONS_EXPECTED_OUTPUT_JSON "
            "not configured."
        )

    response = (
        express_execution_result[
            "response"
        ]
    )

    actual_output = response.get(
        "output"
    )

    assert actual_output is not None

    try:
        expected_output = json.loads(
            STEPFUNCTIONS_EXPECTED_OUTPUT_JSON
        )
    except json.JSONDecodeError as error:
        pytest.fail(
            "STEPFUNCTIONS_EXPECTED_OUTPUT_JSON "
            f"is invalid: {error}"
        )

    assert (
        normalize_json(
            actual_output
        )
        == normalize_json(
            expected_output
        )
    )