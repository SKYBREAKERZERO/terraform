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

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/apigateway/show_apigateway.py"


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
echo "API GATEWAY SHOW"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "API Name:            ${EXPECTED_API_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${APIGATEWAY_ENABLED,,}" != "true" ]]; then
  echo "[INFO] API Gateway is disabled for this environment."
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
  echo "[ERROR] API Gateway show script was not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_apigateway.py exists."


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
# API Gateway API Check
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
# Expected API Existence Check
# ============================================================

echo
echo "Checking expected API Gateway HTTP API..."

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
    "APIGATEWAY_API_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-api"
)

client = boto3.client(
    "apigatewayv2",
    region_name=region,
    endpoint_url=endpoint,
)


def get_apis():
    items = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_apis(
            **kwargs
        )

        items.extend(
            response.get(
                "Items",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return items


try:
    api = next(
        (
            item
            for item in get_apis()
            if item.get("Name") == expected_name
        ),
        None,
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] API Gateway lookup failed: "
        f"{error}"
    )

    sys.exit(1)


if api is None:
    print(
        "[ERROR] Expected API Gateway HTTP API "
        "does not exist:"
    )

    print(
        f"        {expected_name}"
    )

    sys.exit(1)


print(
    "[PASS] API Gateway HTTP API exists:"
)

print(
    f"       Name:     {api.get('Name')}"
)

print(
    f"       API ID:   {api.get('ApiId')}"
)

print(
    f"       Endpoint: {api.get('ApiEndpoint')}"
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
echo "API GATEWAY DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "API GATEWAY SHOW RESULT"
echo "======================================================================"
echo
echo "[PASS] API Gateway information displayed successfully."
echo