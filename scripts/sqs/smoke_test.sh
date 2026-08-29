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

export SQS_FIFO_QUEUE="${SQS_FIFO_QUEUE:-false}"
export SQS_CONTENT_BASED_DEDUPLICATION="${SQS_CONTENT_BASED_DEDUPLICATION:-false}"

export SQS_DEAD_LETTER_QUEUE_ENABLED="${SQS_DEAD_LETTER_QUEUE_ENABLED:-true}"
export SQS_MAX_RECEIVE_COUNT="${SQS_MAX_RECEIVE_COUNT:-5}"

export SQS_VISIBILITY_TIMEOUT_SECONDS="${SQS_VISIBILITY_TIMEOUT_SECONDS:-30}"
export SQS_MESSAGE_RETENTION_SECONDS="${SQS_MESSAGE_RETENTION_SECONDS:-345600}"
export SQS_RECEIVE_WAIT_TIME_SECONDS="${SQS_RECEIVE_WAIT_TIME_SECONDS:-20}"
export SQS_DELAY_SECONDS="${SQS_DELAY_SECONDS:-0}"
export SQS_MAX_MESSAGE_SIZE="${SQS_MAX_MESSAGE_SIZE:-262144}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Paths
# ============================================================

TEST_FILE="${PROJECT_ROOT}/python/tests/sqs/test_sqs.py"


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
echo "SQS SMOKE TEST"
separator

echo "Project Root:        ${PROJECT_ROOT}"
echo "LocalStack Endpoint: ${LOCALSTACK_ENDPOINT}"
echo "AWS Region:          ${AWS_REGION}"
echo "Project Name:        ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "FIFO Queue:          ${SQS_FIFO_QUEUE}"
echo "DLQ Enabled:         ${SQS_DEAD_LETTER_QUEUE_ENABLED}"

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
  fail "SQS test file not found: ${TEST_FILE}"
fi

echo "[PASS] SQS test file exists"


# ============================================================
# LocalStack SQS API Check
# ============================================================

echo

separator
echo "LOCALSTACK SQS CHECK"
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

try:
    client = boto3.client(
        "sqs",
        region_name=region,
        endpoint_url=endpoint,
    )

    client.list_queues()

except Exception as error:
    print(
        f"[FAIL] SQS endpoint unavailable: {error}"
    )
    sys.exit(1)

print(
    "[PASS] SQS API is reachable"
)
PY
then
  fail "LocalStack SQS API check failed."
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
echo "SQS SMOKE TEST RESULT"
separator


if [[ ${PYTEST_EXIT_CODE} -eq 0 ]]; then
  echo "[PASS] SQS smoke tests passed."
  exit 0
fi


echo "[FAIL] SQS smoke tests failed."
echo "Pytest exit code: ${PYTEST_EXIT_CODE}"

exit "${PYTEST_EXIT_CODE}"