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

VALIDATE_SCRIPT="${PROJECT_ROOT}/python/src/dynamodb/validate_dynamodb.py"


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

export DYNAMODB_HASH_KEY="${DYNAMODB_HASH_KEY:-id}"
export DYNAMODB_HASH_KEY_TYPE="${DYNAMODB_HASH_KEY_TYPE:-S}"

export DYNAMODB_RANGE_KEY="${DYNAMODB_RANGE_KEY:-}"
export DYNAMODB_RANGE_KEY_TYPE="${DYNAMODB_RANGE_KEY_TYPE:-S}"

export DYNAMODB_BILLING_MODE="${
  DYNAMODB_BILLING_MODE:-PAY_PER_REQUEST
}"

export DYNAMODB_READ_CAPACITY="${DYNAMODB_READ_CAPACITY:-5}"
export DYNAMODB_WRITE_CAPACITY="${DYNAMODB_WRITE_CAPACITY:-5}"

export DYNAMODB_TTL_ENABLED="${DYNAMODB_TTL_ENABLED:-false}"

export DYNAMODB_TTL_ATTRIBUTE_NAME="${
  DYNAMODB_TTL_ATTRIBUTE_NAME:-expires_at
}"

export DYNAMODB_POINT_IN_TIME_RECOVERY_ENABLED="${
  DYNAMODB_POINT_IN_TIME_RECOVERY_ENABLED:-false
}"

export DYNAMODB_SERVER_SIDE_ENCRYPTION_ENABLED="${
  DYNAMODB_SERVER_SIDE_ENCRYPTION_ENABLED:-true
}"

export DYNAMODB_STREAM_ENABLED="${DYNAMODB_STREAM_ENABLED:-false}"

export DYNAMODB_STREAM_VIEW_TYPE="${
  DYNAMODB_STREAM_VIEW_TYPE:-NEW_AND_OLD_IMAGES
}"

export DYNAMODB_DELETION_PROTECTION_ENABLED="${
  DYNAMODB_DELETION_PROTECTION_ENABLED:-false
}"

export DYNAMODB_TABLE_CLASS="${
  DYNAMODB_TABLE_CLASS:-STANDARD
}"

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
echo "DYNAMODB VALIDATION"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Table:               ${EXPECTED_TABLE_NAME}"
echo "Hash Key:            ${DYNAMODB_HASH_KEY}"
echo "Range Key:           ${DYNAMODB_RANGE_KEY:-none}"
echo "Billing Mode:        ${DYNAMODB_BILLING_MODE}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${DYNAMODB_ENABLED,,}" != "true" ]]; then
  echo "[PASS] DynamoDB is disabled for this environment."
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
# Validator File Check
# ============================================================

if [[ ! -f "${VALIDATE_SCRIPT}" ]]; then
  echo "[ERROR] DynamoDB validator was not found:"
  echo "  ${VALIDATE_SCRIPT}"
  exit 1
fi

echo "[PASS] validate_dynamodb.py exists."


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

status = table.get(
    "TableStatus"
)

if status != "ACTIVE":
    print(
        "[ERROR] DynamoDB table is not ACTIVE:"
    )

    print(
        f"        Status: {status}"
    )

    sys.exit(1)

print(
    "[PASS] DynamoDB table exists and is ACTIVE:"
)

print(
    f"       Name: {table.get('TableName')}"
)

print(
    f"       ARN:  {table.get('TableArn')}"
)
PY
then
  exit 1
fi


# ============================================================
# Validation Configuration
# ============================================================

echo
echo "======================================================================"
echo "VALIDATION CONFIGURATION"
echo "======================================================================"
echo

echo "Table:"
echo "  ${EXPECTED_TABLE_NAME}"

echo
echo "Keys:"
echo "  Hash Key:       ${DYNAMODB_HASH_KEY}"
echo "  Hash Key Type:  ${DYNAMODB_HASH_KEY_TYPE}"
echo "  Range Key:      ${DYNAMODB_RANGE_KEY:-none}"
echo "  Range Key Type: ${DYNAMODB_RANGE_KEY_TYPE}"

echo
echo "Billing:"
echo "  Mode:           ${DYNAMODB_BILLING_MODE}"
echo "  Read Capacity:  ${DYNAMODB_READ_CAPACITY}"
echo "  Write Capacity: ${DYNAMODB_WRITE_CAPACITY}"

echo
echo "TTL:"
echo "  Enabled:   ${DYNAMODB_TTL_ENABLED}"
echo "  Attribute: ${DYNAMODB_TTL_ATTRIBUTE_NAME}"

echo
echo "Point-in-Time Recovery:"
echo "  ${DYNAMODB_POINT_IN_TIME_RECOVERY_ENABLED}"

echo
echo "Server-Side Encryption:"
echo "  ${DYNAMODB_SERVER_SIDE_ENCRYPTION_ENABLED}"

echo
echo "Streams:"
echo "  Enabled: ${DYNAMODB_STREAM_ENABLED}"
echo "  View:    ${DYNAMODB_STREAM_VIEW_TYPE}"

echo
echo "Deletion Protection:"
echo "  ${DYNAMODB_DELETION_PROTECTION_ENABLED}"

echo
echo "Table Class:"
echo "  ${DYNAMODB_TABLE_CLASS}"

if [[ -n "${DYNAMODB_KMS_KEY_ARN:-}" ]]; then
  echo
  echo "Strict KMS Validation:"
  echo "  enabled"
else
  echo
  echo "Strict KMS Validation:"
  echo "  disabled"
fi

echo


# ============================================================
# Run Validator
# ============================================================

echo "======================================================================"
echo "RUNNING DYNAMODB VALIDATION"
echo "======================================================================"
echo

set +e

python3 "${VALIDATE_SCRIPT}"

VALIDATE_EXIT_CODE=$?

set -e


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "DYNAMODB VALIDATION RESULT"
echo "======================================================================"

if [[ ${VALIDATE_EXIT_CODE} -eq 0 ]]; then

  echo
  echo "[PASS] DynamoDB validation completed successfully."
  echo

else

  echo
  echo "[FAIL] DynamoDB validation failed."
  echo "       validator exit code: ${VALIDATE_EXIT_CODE}"
  echo

fi

exit "${VALIDATE_EXIT_CODE}"