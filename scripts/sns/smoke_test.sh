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
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"

export PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
export ENVIRONMENT="${ENVIRONMENT:-localstack}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

export PYTHONPATH="${PROJECT_ROOT}/python/src"


# ============================================================
# Paths
# ============================================================

TEST_FILE="${PROJECT_ROOT}/python/tests/sns/test_sns.py"


# ============================================================
# Helpers
# ============================================================

print_separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}


fail() {
  echo "[FAIL] $1"
  exit 1
}


# ============================================================
# Header
# ============================================================

print_separator
echo "SNS SMOKE TEST"
print_separator

echo "Project Root:        ${PROJECT_ROOT}"
echo "LocalStack Endpoint: ${LOCALSTACK_ENDPOINT}"
echo "AWS Region:          ${AWS_REGION}"
echo "Project Name:        ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"

echo


# ============================================================
# Prerequisite Checks
# ============================================================

print_separator
echo "PREREQUISITE CHECKS"
print_separator


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
  fail "SNS test file not found: ${TEST_FILE}"
fi

echo "[PASS] SNS test file exists"


# ============================================================
# LocalStack Check
# ============================================================

echo

print_separator
echo "LOCALSTACK CHECK"
print_separator


if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


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
        "sns",
        region_name=region,
        endpoint_url=endpoint,
    )

    client.list_topics()

except (BotoCoreError, ClientError, Exception) as error:
    print(
        f"[FAIL] SNS endpoint unavailable: {error}"
    )
    sys.exit(1)

print(
    "[PASS] SNS API is reachable"
)
PY
then
  fail "LocalStack SNS API check failed."
fi


# ============================================================
# Pytest
# ============================================================

echo

print_separator
echo "PYTEST"
print_separator


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

print_separator
echo "SNS SMOKE TEST RESULT"
print_separator


if [[ ${PYTEST_EXIT_CODE} -eq 0 ]]; then
  echo "[PASS] SNS smoke tests passed."
  exit 0
fi


echo "[FAIL] SNS smoke tests failed."
echo "Pytest exit code: ${PYTEST_EXIT_CODE}"

exit "${PYTEST_EXIT_CODE}"