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

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/kinesis/show_kinesis.py"


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
echo "KINESIS SHOW"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Stream:              ${EXPECTED_STREAM_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${KINESIS_ENABLED,,}" != "true" ]]; then
  echo "[INFO] Kinesis is disabled for this environment."
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
# Show Script Check
# ============================================================

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  echo "[ERROR] Kinesis show script was not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_kinesis.py exists."


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
    f"       Name:   {summary.get('StreamName')}"
)

print(
    f"       ARN:    {summary.get('StreamARN')}"
)

print(
    f"       Status: {status}"
)
PY
then
  exit 1
fi


# ============================================================
# Run Show Script
# ============================================================

echo
echo "======================================================================"
echo "KINESIS DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "KINESIS SHOW RESULT"
echo "======================================================================"
echo
echo "[PASS] Kinesis information displayed successfully."
echo