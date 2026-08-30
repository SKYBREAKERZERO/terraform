#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
)"

PROJECT_ROOT="$(
  cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1
  pwd
)"

TEST_FILE="${PROJECT_ROOT}/python/tests/stepfunctions/test_stepfunctions.py"


# ============================================================
# Environment Defaults
# ============================================================

export LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-test}"

export PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
export ENVIRONMENT="${ENVIRONMENT:-localstack}"

export STEPFUNCTIONS_STATE_MACHINE_TYPE="${STEPFUNCTIONS_STATE_MACHINE_TYPE:-STANDARD}"

export STEPFUNCTIONS_LOGGING_ENABLED="${STEPFUNCTIONS_LOGGING_ENABLED:-false}"
export STEPFUNCTIONS_LOG_LEVEL="${STEPFUNCTIONS_LOG_LEVEL:-ALL}"
export STEPFUNCTIONS_INCLUDE_EXECUTION_DATA="${STEPFUNCTIONS_INCLUDE_EXECUTION_DATA:-true}"

export STEPFUNCTIONS_TRACING_ENABLED="${STEPFUNCTIONS_TRACING_ENABLED:-false}"

export STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS="${STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS:-30}"
export STEPFUNCTIONS_POLL_INTERVAL_SECONDS="${STEPFUNCTIONS_POLL_INTERVAL_SECONDS:-0.5}"

export STEPFUNCTIONS_EXECUTION_INPUT_JSON="${STEPFUNCTIONS_EXECUTION_INPUT_JSON:-{\"order_id\":\"pytest-order-001\",\"source\":\"pytest\"}}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected State Machine Name
# ============================================================

if [[ -n "${STEPFUNCTIONS_STATE_MACHINE_NAME:-}" ]]; then
  EXPECTED_STATE_MACHINE_NAME="${STEPFUNCTIONS_STATE_MACHINE_NAME}"
else
  EXPECTED_STATE_MACHINE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-workflow"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "STEP FUNCTIONS SMOKE TEST"
echo "======================================================================"
echo
echo "Project Root:       ${PROJECT_ROOT}"
echo "Endpoint:           ${LOCALSTACK_ENDPOINT}"
echo "Region:             ${AWS_REGION}"
echo "Project:            ${PROJECT_NAME}"
echo "Environment:        ${ENVIRONMENT}"
echo "State Machine:      ${EXPECTED_STATE_MACHINE_NAME}"
echo "Type:               ${STEPFUNCTIONS_STATE_MACHINE_TYPE}"
echo "Logging Enabled:    ${STEPFUNCTIONS_LOGGING_ENABLED}"
echo "Tracing Enabled:    ${STEPFUNCTIONS_TRACING_ENABLED}"
echo "Execution Timeout:  ${STEPFUNCTIONS_EXECUTION_TIMEOUT_SECONDS}s"
echo "Poll Interval:      ${STEPFUNCTIONS_POLL_INTERVAL_SECONDS}s"
echo


# ============================================================
# Python Check
# ============================================================

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 is not installed or not available in PATH."
  exit 1
fi

echo "[PASS] python3 is available."


# ============================================================
# boto3 Check
# ============================================================

if ! python3 -c "import boto3" >/dev/null 2>&1; then
  echo "[ERROR] boto3 is not installed."
  echo
  echo "Install with:"
  echo "  python3 -m pip install boto3"
  exit 1
fi

echo "[PASS] boto3 is available."


# ============================================================
# pytest Check
# ============================================================

if ! python3 -c "import pytest" >/dev/null 2>&1; then
  echo "[ERROR] pytest is not installed."
  echo
  echo "Install with:"
  echo "  python3 -m pip install pytest"
  exit 1
fi

echo "[PASS] pytest is available."


# ============================================================
# Test File Check
# ============================================================

if [[ ! -f "${TEST_FILE}" ]]; then
  echo "[ERROR] Step Functions test file was not found:"
  echo "  ${TEST_FILE}"
  exit 1
fi

echo "[PASS] test_stepfunctions.py exists."


# ============================================================
# LocalStack Health Check
# ============================================================

echo
echo "Checking LocalStack..."

if command -v curl >/dev/null 2>&1; then

  if curl \
    --silent \
    --fail \
    "${LOCALSTACK_ENDPOINT}/_localstack/health" \
    >/dev/null 2>&1; then

    echo "[PASS] LocalStack is reachable."

  else

    echo "[ERROR] LocalStack is not reachable:"
    echo "  ${LOCALSTACK_ENDPOINT}"

    exit 1
  fi

else

  echo "[WARN] curl is not installed."
  echo "[WARN] Skipping LocalStack HTTP health check."

fi


# ============================================================
# Step Functions API Check
# ============================================================

echo
echo "Checking Step Functions API..."

python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]


client = boto3.client(
    "stepfunctions",
    region_name=region,
    endpoint_url=endpoint,
)


try:
    response = client.list_state_machines(
        maxResults=1,
    )

except (ClientError, BotoCoreError) as error:
    print(
        "[ERROR] Step Functions API "
        f"is not available: {error}"
    )

    sys.exit(1)


status_code = response.get(
    "ResponseMetadata",
    {},
).get(
    "HTTPStatusCode"
)


if status_code != 200:
    print(
        "[ERROR] Unexpected Step Functions "
        f"HTTP status: {status_code}"
    )

    sys.exit(1)


print(
    "[PASS] Step Functions API is available."
)
PY


# ============================================================
# State Machine Existence Check
# ============================================================

echo
echo "Checking expected State Machine..."

python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "STEPFUNCTIONS_STATE_MACHINE_NAME"
)


expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-workflow"
)


client = boto3.client(
    "stepfunctions",
    region_name=region,
    endpoint_url=endpoint,
)


try:
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["nextToken"] = next_token

        response = client.list_state_machines(
            **kwargs
        )

        for machine in response.get(
            "stateMachines",
            [],
        ):
            if machine.get("name") == expected_name:
                arn = machine.get(
                    "stateMachineArn"
                )

                print(
                    "[PASS] State Machine exists:"
                )

                print(
                    f"       Name: {expected_name}"
                )

                print(
                    f"       ARN:  {arn}"
                )

                sys.exit(0)

        next_token = response.get(
            "nextToken"
        )

        if not next_token:
            break


except (ClientError, BotoCoreError) as error:
    print(
        "[ERROR] Failed while searching "
        f"for State Machine: {error}"
    )

    sys.exit(1)


print(
    "[ERROR] Expected State Machine "
    "does not exist:"
)

print(
    f"        {expected_name}"
)

sys.exit(1)
PY


# ============================================================
# Configuration Summary
# ============================================================

echo
echo "======================================================================"
echo "PYTEST CONFIGURATION"
echo "======================================================================"
echo

echo "State Machine:"
echo "  ${EXPECTED_STATE_MACHINE_NAME}"

echo
echo "Execution Input:"
echo "  ${STEPFUNCTIONS_EXECUTION_INPUT_JSON}"

if [[ -n "${STEPFUNCTIONS_ROLE_ARN:-}" ]]; then
  echo
  echo "Expected Role ARN:"
  echo "  ${STEPFUNCTIONS_ROLE_ARN}"
fi

if [[ -n "${STEPFUNCTIONS_DEFINITION_JSON:-}" ]]; then
  echo
  echo "Strict ASL Validation:"
  echo "  enabled"
else
  echo
  echo "Strict ASL Validation:"
  echo "  disabled"
fi

if [[ -n "${STEPFUNCTIONS_EXPECTED_OUTPUT_JSON:-}" ]]; then
  echo
  echo "Strict Output Validation:"
  echo "  enabled"
else
  echo
  echo "Strict Output Validation:"
  echo "  disabled"
fi

echo


# ============================================================
# Run Pytest
# ============================================================

echo "======================================================================"
echo "RUNNING STEP FUNCTIONS TESTS"
echo "======================================================================"
echo

set +e

python3 -m pytest \
  "${TEST_FILE}" \
  -v \
  --tb=short

PYTEST_EXIT_CODE=$?

set -e


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "STEP FUNCTIONS SMOKE TEST RESULT"
echo "======================================================================"

if [[ ${PYTEST_EXIT_CODE} -eq 0 ]]; then

  echo
  echo "[PASS] Step Functions smoke test completed successfully."
  echo

else

  echo
  echo "[FAIL] Step Functions smoke test failed."
  echo "       pytest exit code: ${PYTEST_EXIT_CODE}"
  echo

fi


exit "${PYTEST_EXIT_CODE}"