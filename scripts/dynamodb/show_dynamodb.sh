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

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/dynamodb/show_dynamodb.py"


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

export DYNAMODB_ENABLED="${DYNAMODB_ENABLED:-true}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected Table Name
# ============================================================

if [[ -n "${DYNAMODB_TABLE_NAME:-}" ]]; then
  EXPECTED_TABLE_NAME="${DYNAMODB_TABLE_NAME}"
else
  EXPECTED_TABLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-table"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "DYNAMODB SHOW"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Table:               ${EXPECTED_TABLE_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${DYNAMODB_ENABLED,,}" != "true" ]]; then
  echo "[INFO] DynamoDB is disabled for this environment."
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
  echo "[ERROR] DynamoDB show script was not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_dynamodb.py exists."


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
# DynamoDB API Check
# ============================================================

echo
echo "Checking DynamoDB API..."

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
    "dynamodb",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.list_tables(
        Limit=1,
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] DynamoDB API check failed: "
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
        "[ERROR] Unexpected DynamoDB API "
        f"HTTP status: {status_code}"
    )
    sys.exit(1)

print(
    "[PASS] DynamoDB API is available."
)
PY
then
  exit 1
fi


# ============================================================
# Expected Table Existence Check
# ============================================================

echo
echo "Checking expected DynamoDB table..."

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
    "DYNAMODB_TABLE_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-table"
)

client = boto3.client(
    "dynamodb",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.describe_table(
        TableName=expected_name,
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
            "[ERROR] Expected DynamoDB table "
            "does not exist:"
        )
        print(
            f"        {expected_name}"
        )

    else:
        print(
            "[ERROR] DynamoDB table check failed: "
            f"{error}"
        )

    sys.exit(1)

except BotoCoreError as error:
    print(
        "[ERROR] DynamoDB SDK check failed: "
        f"{error}"
    )
    sys.exit(1)


table = response.get(
    "Table",
    {},
)

print(
    "[PASS] DynamoDB table exists:"
)

print(
    f"       Name:   {table.get('TableName')}"
)

print(
    f"       ARN:    {table.get('TableArn')}"
)

print(
    f"       Status: {table.get('TableStatus')}"
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
echo "DYNAMODB DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "DYNAMODB SHOW RESULT"
echo "======================================================================"
echo
echo "[PASS] DynamoDB information displayed successfully."
echo