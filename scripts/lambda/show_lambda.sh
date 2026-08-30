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

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/lambda/show_lambda.py"


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

export LAMBDA_RUNTIME="${LAMBDA_RUNTIME:-python3.13}"
export LAMBDA_HANDLER="${LAMBDA_HANDLER:-lambda_function.lambda_handler}"

export LAMBDA_MEMORY_SIZE="${LAMBDA_MEMORY_SIZE:-128}"
export LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-30}"
export LAMBDA_EPHEMERAL_STORAGE_SIZE="${LAMBDA_EPHEMERAL_STORAGE_SIZE:-512}"

export LAMBDA_TRACING_MODE="${LAMBDA_TRACING_MODE:-PassThrough}"
export LAMBDA_RESERVED_CONCURRENT_EXECUTIONS="${LAMBDA_RESERVED_CONCURRENT_EXECUTIONS:--1}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected Lambda Function Name
# ============================================================

if [[ -n "${LAMBDA_FUNCTION_NAME:-}" ]]; then
  EXPECTED_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME}"
else
  EXPECTED_FUNCTION_NAME="${PROJECT_NAME}-${ENVIRONMENT}-function"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "LAMBDA SHOW"
echo "======================================================================"
echo
echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Function:            ${EXPECTED_FUNCTION_NAME}"
echo "Runtime:             ${LAMBDA_RUNTIME}"
echo "Handler:             ${LAMBDA_HANDLER}"
echo "Memory:              ${LAMBDA_MEMORY_SIZE} MB"
echo "Timeout:             ${LAMBDA_TIMEOUT}s"
echo "Ephemeral Storage:   ${LAMBDA_EPHEMERAL_STORAGE_SIZE} MB"
echo "Tracing:             ${LAMBDA_TRACING_MODE}"
echo "Concurrency:         ${LAMBDA_RESERVED_CONCURRENT_EXECUTIONS}"
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
# Show Script Check
# ============================================================

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  echo "[ERROR] Lambda show script was not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_lambda.py exists."


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
# Lambda API Check
# ============================================================

echo
echo "Checking Lambda API..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]


client = boto3.client(
    "lambda",
    region_name=region,
    endpoint_url=endpoint,
)


try:
    response = client.list_functions(
        MaxItems=1,
    )

except (ClientError, BotoCoreError) as error:
    print(
        "[ERROR] Lambda API check failed: "
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
        "[ERROR] Unexpected Lambda API "
        f"HTTP status: {status_code}"
    )
    sys.exit(1)


print(
    "[PASS] Lambda API is available."
)
PY
then
  exit 1
fi


# ============================================================
# Lambda Function Existence Check
# ============================================================

echo
echo "Checking expected Lambda function..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "LAMBDA_FUNCTION_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-function"
)


client = boto3.client(
    "lambda",
    region_name=region,
    endpoint_url=endpoint,
)


try:
    response = client.get_function_configuration(
        FunctionName=expected_name,
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
            "[ERROR] Expected Lambda function "
            "does not exist:"
        )
        print(
            f"        {expected_name}"
        )
    else:
        print(
            "[ERROR] Lambda function check failed: "
            f"{error}"
        )

    sys.exit(1)

except BotoCoreError as error:
    print(
        "[ERROR] Lambda SDK check failed: "
        f"{error}"
    )
    sys.exit(1)


print(
    "[PASS] Lambda function exists:"
)

print(
    f"       Name: {response.get('FunctionName')}"
)

print(
    f"       ARN:  {response.get('FunctionArn')}"
)
PY
then
  exit 1
fi


# ============================================================
# Execute Show Script
# ============================================================

echo
echo "======================================================================"
echo "LAMBDA RESOURCE DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"