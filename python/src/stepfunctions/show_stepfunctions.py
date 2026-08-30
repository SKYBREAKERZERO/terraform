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

STEPFUNCTIONS_STATE_MACHINE_NAME = os.getenv(
    "STEPFUNCTIONS_STATE_MACHINE_NAME",
)

STEPFUNCTIONS_STATE_MACHINE_TYPE = os.getenv(
    "STEPFUNCTIONS_STATE_MACHINE_TYPE",
    "STANDARD",
)

STEPFUNCTIONS_LOGGING_ENABLED = os.getenv(
    "STEPFUNCTIONS_LOGGING_ENABLED",
    "false",
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
# State Machines
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

        state_machine_arn = state_machine.get(
            "stateMachineArn"
        )

        if state_machine_arn:
            return state_machine_arn

    raise RuntimeError(
        "Step Functions state machine not found: "
        f"{EXPECTED_STATE_MACHINE_NAME}"
    )


def get_state_machine_details(
    client,
    state_machine_arn,
):
    return client.describe_state_machine(
        stateMachineArn=state_machine_arn,
    )


# ============================================================
# Tags
# ============================================================

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
    if value is None:
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


def format_datetime(
    value,
):
    if value is None:
        return ""

    if hasattr(
        value,
        "isoformat",
    ):
        return value.isoformat()

    return str(
        value
    )


# ============================================================
# State Machine Output
# ============================================================

def print_state_machine(
    state_machine_arn,
    details,
):
    print_separator()
    print("STEP FUNCTIONS STATE MACHINE")
    print_separator()

    print(
        f"Name:             "
        f"{details.get('name', EXPECTED_STATE_MACHINE_NAME)}"
    )

    print(
        f"ARN:              "
        f"{state_machine_arn}"
    )

    print(
        f"Status:           "
        f"{details.get('status', '')}"
    )

    print(
        f"Type:             "
        f"{details.get('type', '')}"
    )

    print(
        f"Role ARN:         "
        f"{details.get('roleArn', '')}"
    )

    print(
        f"Creation Date:    "
        f"{format_datetime(details.get('creationDate'))}"
    )


# ============================================================
# Definition Output
# ============================================================

def print_definition(
    details,
):
    print()

    print_separator()
    print("ASL DEFINITION")
    print_separator()

    definition = details.get(
        "definition"
    )

    if not definition:
        print(
            "No state machine definition found."
        )
        return

    print(
        format_json(
            definition
        )
    )


# ============================================================
# Logging Output
# ============================================================

def print_logging_configuration(
    details,
):
    print()

    print_separator()
    print("LOGGING")
    print_separator()

    logging_configuration = details.get(
        "loggingConfiguration",
        {},
    )

    level = logging_configuration.get(
        "level",
        "OFF",
    )

    include_execution_data = (
        logging_configuration.get(
            "includeExecutionData",
            False,
        )
    )

    destinations = logging_configuration.get(
        "destinations",
        [],
    )

    print(
        f"Configured:       "
        f"{str(STEPFUNCTIONS_LOGGING_ENABLED).lower()}"
    )

    print(
        f"Level:            "
        f"{level}"
    )

    print(
        f"Execution Data:   "
        f"{str(include_execution_data).lower()}"
    )

    if not destinations:
        print(
            "Destination:      none"
        )
        return

    for destination in destinations:
        cloudwatch_logs = destination.get(
            "cloudWatchLogsLogGroup",
            {},
        )

        log_group_arn = cloudwatch_logs.get(
            "logGroupArn"
        )

        print(
            f"Destination:      "
            f"{log_group_arn or ''}"
        )


# ============================================================
# Tracing Output
# ============================================================

def print_tracing_configuration(
    details,
):
    print()

    print_separator()
    print("X-RAY TRACING")
    print_separator()

    tracing_configuration = details.get(
        "tracingConfiguration",
        {},
    )

    enabled = tracing_configuration.get(
        "enabled",
        False,
    )

    print(
        f"Configured:       "
        f"{str(STEPFUNCTIONS_TRACING_ENABLED).lower()}"
    )

    print(
        f"Enabled:          "
        f"{str(enabled).lower()}"
    )


# ============================================================
# Tags Output
# ============================================================

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

    for key in sorted(
        tags
    ):
        print(
            f"{key}={tags[key]}"
        )


# ============================================================
# Run
# ============================================================

def run():
    client = create_stepfunctions_client()

    state_machine_arn = get_state_machine_arn(
        client
    )

    details = get_state_machine_details(
        client,
        state_machine_arn,
    )

    tags = get_state_machine_tags(
        client,
        state_machine_arn,
    )

    print_state_machine(
        state_machine_arn,
        details,
    )

    print_definition(
        details
    )

    print_logging_configuration(
        details
    )

    print_tracing_configuration(
        details
    )

    print_tags(
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
        RuntimeError,
        TypeError,
        ValueError,
    ) as error:
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
    sys.exit(
        main()
    )