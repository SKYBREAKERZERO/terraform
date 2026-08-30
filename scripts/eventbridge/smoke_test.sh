#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Project Root
# ============================================================

PROJECT_ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." &&
  pwd
)"


# ============================================================
# Environment
# ============================================================

export LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"

export PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
export ENVIRONMENT="${ENVIRONMENT:-localstack}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-test}"

export EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS="${EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS:-true}"

export EVENTBRIDGE_RULES_JSON="${EVENTBRIDGE_RULES_JSON:-{}}"
export EVENTBRIDGE_TARGETS_JSON="${EVENTBRIDGE_TARGETS_JSON:-{}}"

export EVENTBRIDGE_TEST_SOURCE="${EVENTBRIDGE_TEST_SOURCE:-pytest.eventbridge}"
export EVENTBRIDGE_TEST_DETAIL_TYPE="${EVENTBRIDGE_TEST_DETAIL_TYPE:-PytestEvent}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Paths
# ============================================================

TEST_FILE="${PROJECT_ROOT}/python/tests/eventbridge/test_eventbridge.py"


# ============================================================
# Helpers
# ============================================================

separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}


fail() {
  echo "[FAIL] $1"
  exit 1
}


# ============================================================
# Header
# ============================================================

separator
echo "EVENTBRIDGE SMOKE TEST"
separator

echo "Project Root:        ${PROJECT_ROOT}"
echo "LocalStack Endpoint: ${LOCALSTACK_ENDPOINT}"
echo "AWS Region:          ${AWS_REGION}"
echo "Project Name:        ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Custom Event Bus:    ${EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS}"

if [[ -n "${EVENTBRIDGE_EVENT_BUS_NAME:-}" ]]; then
  echo "Event Bus Name:      ${EVENTBRIDGE_EVENT_BUS_NAME}"
else
  echo "Event Bus Name:      auto"
fi

echo


# ============================================================
# Prerequisite Checks
# ============================================================

separator
echo "PREREQUISITE CHECKS"
separator


if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is not installed or not in PATH."
fi

echo "[PASS] python3 found"


if ! python3 -c "import boto3" >/dev/null 2>&1; then
  fail "Python package boto3 is not installed."
fi

echo "[PASS] boto3 installed"


if ! python3 -c "import pytest" >/dev/null 2>&1; then
  fail "Python package pytest is not installed."
fi

echo "[PASS] pytest installed"


if [[ ! -f "${TEST_FILE}" ]]; then
  fail "EventBridge test file not found: ${TEST_FILE}"
fi

echo "[PASS] EventBridge test file exists"


# ============================================================
# LocalStack EventBridge API Check
# ============================================================

echo

separator
echo "LOCALSTACK EVENTBRIDGE CHECK"
separator


if ! python3 - <<'PY'
import os
import sys

import boto3


endpoint = os.getenv(
    "LOCALSTACK_ENDPOINT",
    "http://localhost:4566",
)

region = os.getenv(
    "AWS_REGION",
    "ap-northeast-1",
)

custom_bus = os.getenv(
    "EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS",
    "true",
).lower() == "true"

configured_bus_name = os.getenv(
    "EVENTBRIDGE_EVENT_BUS_NAME",
)

project_name = os.getenv(
    "PROJECT_NAME",
    "aws-enterprise-lab",
)

environment = os.getenv(
    "ENVIRONMENT",
    "localstack",
)

event_bus_name = (
    (
        configured_bus_name
        if configured_bus_name
        else f"{project_name}-{environment}-events"
    )
    if custom_bus
    else "default"
)

try:
    client = boto3.client(
        "events",
        region_name=region,
        endpoint_url=endpoint,
    )

    client.describe_event_bus(
        Name=event_bus_name,
    )

except Exception as error:
    print(
        "[FAIL] EventBridge endpoint or event bus "
        f"unavailable: {error}"
    )
    sys.exit(1)

print(
    "[PASS] EventBridge API is reachable "
    f"and event bus exists: {event_bus_name}"
)
PY
then
  fail "LocalStack EventBridge API check failed."
fi


# ============================================================
# Pytest
# ============================================================

echo

separator
echo "PYTEST"
separator


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

separator
echo "EVENTBRIDGE SMOKE TEST RESULT"
separator


if [[ ${PYTEST_EXIT_CODE} -eq 0 ]]; then
  echo "[PASS] EventBridge smoke tests passed."
  exit 0
fi


echo "[FAIL] EventBridge smoke tests failed."
echo "Pytest exit code: ${PYTEST_EXIT_CODE}"

exit "${PYTEST_EXIT_CODE}"