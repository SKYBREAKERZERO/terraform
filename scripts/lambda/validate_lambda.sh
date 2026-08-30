#!/usr/bin/env bash

set -u
set -o pipefail


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

VALIDATOR="${PROJECT_ROOT}/python/src/lambda/validate_lambda.py"


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

export LAMBDA_ARCHITECTURES_JSON="${LAMBDA_ARCHITECTURES_JSON:-[\"x86_64\"]}"

export LAMBDA_MEMORY_SIZE="${LAMBDA_MEMORY_SIZE:-128}"
export LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-30}"
export LAMBDA_EPHEMERAL_STORAGE_SIZE="${LAMBDA_EPHEMERAL_STORAGE_SIZE:-512}"

export LAMBDA_ENVIRONMENT_VARIABLES_JSON="${LAMBDA_ENVIRONMENT_VARIABLES_JSON:-{\"ENVIRONMENT\":\"localstack\",\"LOG_LEVEL\":\"INFO\"}}"

export LAMBDA_TRACING_MODE="${LAMBDA_TRACING_MODE:-PassThrough}"

export LAMBDA_RESERVED_CONCURRENT_EXECUTIONS="${LAMBDA_RESERVED_CONCURRENT_EXECUTIONS:--1}"

export LAMBDA_LAYERS_JSON="${LAMBDA_LAYERS_JSON:-[]}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected Function Name
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
echo "LAMBDA VALIDATION"
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
echo "Tracing Mode:        ${LAMBDA_TRACING_MODE}"
echo "Concurrency:         ${LAMBDA_RESERVED_CONCURRENT_EXECUTIONS}"

if [[ -n "${LAMBDA_ROLE_ARN:-}" ]]; then
  echo "Expected Role ARN:   ${LAMBDA_ROLE_ARN}"
else
  echo "Expected Role ARN:   not configured"
fi

if [[ -n "${LAMBDA_KMS_KEY_ARN:-}" ]]; then
  echo "Expected KMS ARN:    ${LAMBDA_KMS_KEY_ARN}"
else
  echo "Expected KMS ARN:    not configured"
fi

if [[ -n "${LAMBDA_SOURCE_CODE_HASH:-}" ]]; then
  echo "Strict Code Hash:    enabled"
else
  echo "Strict Code Hash:    disabled"
fi

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
# Validator File Check
# ============================================================

if [[ ! -f "${VALIDATOR}" ]]; then
  echo "[ERROR] Lambda validator was not found:"
  echo "  ${VALIDATOR}"
  exit 1
fi

echo "[PASS] validate_lambda.py exists."


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
# Run Validator
# ============================================================

echo
echo "======================================================================"
echo "RUNNING LAMBDA VALIDATOR"
echo "======================================================================"
echo

python3 "${VALIDATOR}"

VALIDATOR_EXIT_CODE=$?


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "LAMBDA VALIDATION RESULT"
echo "======================================================================"

if [[ ${VALIDATOR_EXIT_CODE} -eq 0 ]]; then

  echo
  echo "[PASS] Lambda validation completed successfully."
  echo

else

  echo
  echo "[FAIL] Lambda validation failed."
  echo "       validator exit code: ${VALIDATOR_EXIT_CODE}"
  echo

fi


exit "${VALIDATOR_EXIT_CODE}"