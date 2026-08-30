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

VALIDATE_SCRIPT="${PROJECT_ROOT}/python/src/apigateway/validate_apigateway.py"


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

export APIGATEWAY_ENABLED="${APIGATEWAY_ENABLED:-true}"

export APIGATEWAY_PROTOCOL_TYPE="${APIGATEWAY_PROTOCOL_TYPE:-HTTP}"

export APIGATEWAY_INTEGRATION_TYPE="${
  APIGATEWAY_INTEGRATION_TYPE:-AWS_PROXY
}"

export APIGATEWAY_INTEGRATION_METHOD="${
  APIGATEWAY_INTEGRATION_METHOD:-POST
}"

export APIGATEWAY_PAYLOAD_FORMAT_VERSION="${
  APIGATEWAY_PAYLOAD_FORMAT_VERSION:-2.0
}"

export APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS="${
  APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS:-30000
}"

export APIGATEWAY_ROUTE_KEY="${
  APIGATEWAY_ROUTE_KEY:-POST /
}"

export APIGATEWAY_ROUTE_AUTHORIZATION_TYPE="${
  APIGATEWAY_ROUTE_AUTHORIZATION_TYPE:-NONE
}"

export APIGATEWAY_STAGE_NAME="${
  APIGATEWAY_STAGE_NAME:-\$default
}"

export APIGATEWAY_AUTO_DEPLOY="${
  APIGATEWAY_AUTO_DEPLOY:-true
}"

export APIGATEWAY_CORS_ENABLED="${
  APIGATEWAY_CORS_ENABLED:-false
}"

export APIGATEWAY_CORS_ALLOW_ORIGINS_JSON="${
  APIGATEWAY_CORS_ALLOW_ORIGINS_JSON:-[\"*\"]
}"

export APIGATEWAY_CORS_ALLOW_METHODS_JSON="${
  APIGATEWAY_CORS_ALLOW_METHODS_JSON:-[\"GET\",\"POST\",\"OPTIONS\"]
}"

export APIGATEWAY_CORS_ALLOW_HEADERS_JSON="${
  APIGATEWAY_CORS_ALLOW_HEADERS_JSON:-[\"content-type\",\"authorization\"]
}"

export APIGATEWAY_CORS_EXPOSE_HEADERS_JSON="${
  APIGATEWAY_CORS_EXPOSE_HEADERS_JSON:-[]
}"

export APIGATEWAY_CORS_ALLOW_CREDENTIALS="${
  APIGATEWAY_CORS_ALLOW_CREDENTIALS:-false
}"

export APIGATEWAY_CORS_MAX_AGE="${
  APIGATEWAY_CORS_MAX_AGE:-0
}"

export APIGATEWAY_ACCESS_LOGGING_ENABLED="${
  APIGATEWAY_ACCESS_LOGGING_ENABLED:-false
}"

export APIGATEWAY_THROTTLING_BURST_LIMIT="${
  APIGATEWAY_THROTTLING_BURST_LIMIT:-100
}"

export APIGATEWAY_THROTTLING_RATE_LIMIT="${
  APIGATEWAY_THROTTLING_RATE_LIMIT:-50
}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected API Name
# ============================================================

if [[ -n "${APIGATEWAY_API_NAME:-}" ]]; then
  EXPECTED_API_NAME="${APIGATEWAY_API_NAME}"
else
  EXPECTED_API_NAME="${PROJECT_NAME}-${ENVIRONMENT}-api"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "API GATEWAY VALIDATION"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "API Name:            ${EXPECTED_API_NAME}"
echo "Protocol:            ${APIGATEWAY_PROTOCOL_TYPE}"
echo "Route:               ${APIGATEWAY_ROUTE_KEY}"
echo "Stage:               ${APIGATEWAY_STAGE_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${APIGATEWAY_ENABLED,,}" != "true" ]]; then
  echo "[PASS] API Gateway is disabled for this environment."
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
  echo "[ERROR] API Gateway validator was not found:"
  echo "  ${VALIDATE_SCRIPT}"
  exit 1
fi

echo "[PASS] validate_apigateway.py exists."


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
# API Gateway v2 API Check
# ============================================================

echo
echo "Checking API Gateway v2 API..."

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
    "apigatewayv2",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.get_apis(
        MaxResults="1",
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] API Gateway v2 API check failed: "
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
        "[ERROR] Unexpected API Gateway "
        f"HTTP status: {status_code}"
    )

    sys.exit(1)

print(
    "[PASS] API Gateway v2 API is available."
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

echo "API:"
echo "  ${EXPECTED_API_NAME}"

echo
echo "Integration:"
echo "  Type:            ${APIGATEWAY_INTEGRATION_TYPE}"
echo "  Method:          ${APIGATEWAY_INTEGRATION_METHOD}"
echo "  Payload Version: ${APIGATEWAY_PAYLOAD_FORMAT_VERSION}"
echo "  Timeout:         ${APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS} ms"

echo
echo "Route:"
echo "  ${APIGATEWAY_ROUTE_KEY}"

echo
echo "Authorization:"
echo "  ${APIGATEWAY_ROUTE_AUTHORIZATION_TYPE}"

echo
echo "Stage:"
echo "  ${APIGATEWAY_STAGE_NAME}"

echo
echo "Auto Deploy:"
echo "  ${APIGATEWAY_AUTO_DEPLOY}"

echo
echo "CORS:"
echo "  ${APIGATEWAY_CORS_ENABLED}"

echo
echo "Access Logging:"
echo "  ${APIGATEWAY_ACCESS_LOGGING_ENABLED}"

echo
echo "Throttling:"
echo "  Burst: ${APIGATEWAY_THROTTLING_BURST_LIMIT}"
echo "  Rate:  ${APIGATEWAY_THROTTLING_RATE_LIMIT}"

if [[ -n "${APIGATEWAY_INTEGRATION_URI:-}" ]]; then
  echo
  echo "Strict Integration URI Validation:"
  echo "  enabled"
else
  echo
  echo "Strict Integration URI Validation:"
  echo "  disabled"
fi

if [[ -n "${APIGATEWAY_DESCRIPTION:-}" ]]; then
  echo
  echo "Strict Description Validation:"
  echo "  enabled"
else
  echo
  echo "Strict Description Validation:"
  echo "  disabled"
fi

if [[ -n "${APIGATEWAY_AUTHORIZER_ID:-}" ]]; then
  echo
  echo "Strict Authorizer Validation:"
  echo "  enabled"
else
  echo
  echo "Strict Authorizer Validation:"
  echo "  disabled"
fi

echo


# ============================================================
# Run Validator
# ============================================================

echo "======================================================================"
echo "RUNNING API GATEWAY VALIDATION"
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
echo "API GATEWAY VALIDATION RESULT"
echo "======================================================================"

if [[ ${VALIDATE_EXIT_CODE} -eq 0 ]]; then

  echo
  echo "[PASS] API Gateway validation completed successfully."
  echo

else

  echo
  echo "[FAIL] API Gateway validation failed."
  echo "       validator exit code: ${VALIDATE_EXIT_CODE}"
  echo

fi

exit "${VALIDATE_EXIT_CODE}"