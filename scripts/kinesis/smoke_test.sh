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

TEST_FILE="${PROJECT_ROOT}/python/tests/kinesis/test_kinesis.py"


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

export KINESIS_ENABLED="${KINESIS_ENABLED:-true}"

export KINESIS_STREAM_MODE="${KINESIS_STREAM_MODE:-PROVISIONED}"
export KINESIS_SHARD_COUNT="${KINESIS_SHARD_COUNT:-1}"
export KINESIS_RETENTION_PERIOD="${KINESIS_RETENTION_PERIOD:-24}"

export KINESIS_ENCRYPTION_TYPE="${KINESIS_ENCRYPTION_TYPE:-NONE}"
export KINESIS_KMS_KEY_ID="${KINESIS_KMS_KEY_ID:-}"

export KINESIS_SHARD_LEVEL_METRICS="${KINESIS_SHARD_LEVEL_METRICS:-}"

export KINESIS_TEST_PARTITION_KEY="${KINESIS_TEST_PARTITION_KEY:-pytest-partition-001}"
export KINESIS_TEST_DATA="${KINESIS_TEST_DATA:-pytest-kinesis-smoke-test}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected Stream Name
# ============================================================

if [[ -n "${KINESIS_STREAM_NAME:-}" ]]; then
  EXPECTED_STREAM_NAME="${KINESIS_STREAM_NAME}"
else
  EXPECTED_STREAM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-stream"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "KINESIS SMOKE TEST"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Stream:              ${EXPECTED_STREAM_NAME}"
echo "Mode:                ${KINESIS_STREAM_MODE}"
echo "Shard Count:         ${KINESIS_SHARD_COUNT}"
echo "Retention:           ${KINESIS_RETENTION_PERIOD}"
echo "Encryption:          ${KINESIS_ENCRYPTION_TYPE}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${KINESIS_ENABLED,,}" != "true" ]]; then
  echo "[PASS] Kinesis is disabled for this environment."
  echo
  exit 0
fi


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
  echo "[ERROR] Kinesis test file was not found:"
  echo "  ${TEST_FILE}"
  exit 1
fi

echo "[PASS] test_kinesis.py exists."


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
# Kinesis API Check
# ============================================================

echo
echo "Checking Kinesis API..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

client = boto3.client(
    "kinesis",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.list_streams(
        Limit=1,
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] Kinesis API check failed: "
        f"{error}"
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
        "[ERROR] Unexpected Kinesis API "
        f"HTTP status: {status_code}"
    )
    sys.exit(1)

print(
    "[PASS] Kinesis API is available."
)
PY
then
  exit 1
fi


# ============================================================
# Expected Stream Existence Check
# ============================================================

echo
echo "Checking expected Kinesis stream..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "KINESIS_STREAM_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-stream"
)

client = boto3.client(
    "kinesis",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.describe_stream_summary(
        StreamName=expected_name,
    )

except ClientError as error:
    error_info = error.response.get(
        "Error",
        {},
    )

    error_code = error_info.get(
        "Code",
        "Unknown",
    )

    if error_code in {
        "ResourceNotFoundException",
        "ResourceNotFound",
    }:
        print(
            "[ERROR] Expected Kinesis stream "
            "does not exist:"
        )
        print(
            f"        {expected_name}"
        )

    else:
        print(
            "[ERROR] Kinesis stream check failed: "
            f"{error}"
        )

    sys.exit(1)

except BotoCoreError as error:
    print(
        "[ERROR] Kinesis SDK check failed: "
        f"{error}"
    )
    sys.exit(1)


summary = response.get(
    "StreamDescriptionSummary",
    {},
)

status = summary.get(
    "StreamStatus"
)

if status != "ACTIVE":
    print(
        "[ERROR] Kinesis stream is not ACTIVE:"
    )
    print(
        f"        Status: {status}"
    )
    sys.exit(1)

print(
    "[PASS] Kinesis stream exists and is ACTIVE:"
)

print(
    f"       Name: {summary.get('StreamName')}"
)

print(
    f"       ARN:  {summary.get('StreamARN')}"
)
PY
then
  exit 1
fi


# ============================================================
# Pytest Configuration
# ============================================================

echo
echo "======================================================================"
echo "PYTEST CONFIGURATION"
echo "======================================================================"
echo

echo "Stream:"
echo "  ${EXPECTED_STREAM_NAME}"

echo
echo "Capacity:"
echo "  Mode:        ${KINESIS_STREAM_MODE}"
echo "  Shard Count: ${KINESIS_SHARD_COUNT}"

echo
echo "Retention:"
echo "  ${KINESIS_RETENTION_PERIOD} hours"

echo
echo "Encryption:"
echo "  Type: ${KINESIS_ENCRYPTION_TYPE}"

if [[ -n "${KINESIS_KMS_KEY_ID}" ]]; then
  echo "  KMS:  ${KINESIS_KMS_KEY_ID}"
else
  echo "  KMS:  none"
fi

echo
echo "Shard Metrics:"
echo "  ${KINESIS_SHARD_LEVEL_METRICS:-none}"

echo
echo "Runtime Record:"
echo "  Partition Key: ${KINESIS_TEST_PARTITION_KEY}"
echo "  Data:          ${KINESIS_TEST_DATA}"
echo


# ============================================================
# Run Pytest
# ============================================================

echo "======================================================================"
echo "RUNNING KINESIS TESTS"
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
echo "KINESIS SMOKE TEST RESULT"
echo "======================================================================"

if [[ ${PYTEST_EXIT_CODE} -eq 0 ]]; then

  echo
  echo "[PASS] Kinesis smoke test completed successfully."
  echo

else

  echo
  echo "[FAIL] Kinesis smoke test failed."
  echo "       pytest exit code: ${PYTEST_EXIT_CODE}"
  echo

fi

exit "${PYTEST_EXIT_CODE}"