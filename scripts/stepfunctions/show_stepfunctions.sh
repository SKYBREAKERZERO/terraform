#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(
  cd "$(
    dirname "${BASH_SOURCE[0]}"
  )" >/dev/null 2>&1
  && pwd
)"

PROJECT_ROOT="$(
  cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1
  && pwd
)"

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/stepfunctions/show_stepfunctions.py"


# ============================================================
# Environment Defaults
# ============================================================

export LOCALSTACK_ENDPOINT="${
  LOCALSTACK_ENDPOINT:-http://localhost:4566
}"

export AWS_REGION="${
  AWS_REGION:-ap-northeast-1
}"

export AWS_DEFAULT_REGION="${
  AWS_DEFAULT_REGION:-${AWS_REGION}
}"

export AWS_ACCESS_KEY_ID="${
  AWS_ACCESS_KEY_ID:-test
}"

export AWS_SECRET_ACCESS_KEY="${
  AWS_SECRET_ACCESS_KEY:-test
}"

export AWS_SESSION_TOKEN="${
  AWS_SESSION_TOKEN:-test
}"

export PROJECT_NAME="${
  PROJECT_NAME:-aws-enterprise-lab
}"

export ENVIRONMENT="${
  ENVIRONMENT:-localstack
}"

export STEPFUNCTIONS_STATE_MACHINE_TYPE="${
  STEPFUNCTIONS_STATE_MACHINE_TYPE:-STANDARD
}"

export STEPFUNCTIONS_LOGGING_ENABLED="${
  STEPFUNCTIONS_LOGGING_ENABLED:-false
}"

export STEPFUNCTIONS_TRACING_ENABLED="${
  STEPFUNCTIONS_TRACING_ENABLED:-false
}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected State Machine Name
# ============================================================

if [[ -n "${STEPFUNCTIONS_STATE_MACHINE_NAME:-}" ]]; then
  EXPECTED_STATE_MACHINE_NAME="${STEPFUNCTIONS_STATE_MACHINE_NAME}"
else
  EXPECTED_STATE_MACHINE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-workflow"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "STEP FUNCTIONS SHOW"
echo "======================================================================"
echo
echo "Project Root:      ${PROJECT_ROOT}"
echo "Endpoint:          ${LOCALSTACK_ENDPOINT}"
echo "Region:            ${AWS_REGION}"
echo "Project:           ${PROJECT_NAME}"
echo "Environment:       ${ENVIRONMENT}"
echo "State Machine:     ${EXPECTED_STATE_MACHINE_NAME}"
echo "Type:              ${STEPFUNCTIONS_STATE_MACHINE_TYPE}"
echo "Logging Enabled:   ${STEPFUNCTIONS_LOGGING_ENABLED}"
echo "Tracing Enabled:   ${STEPFUNCTIONS_TRACING_ENABLED}"
echo


# ============================================================
# Prerequisite - Python
# ============================================================

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 is not installed or not available in PATH."
  exit 1
fi

echo "[PASS] python3 is available."


# ============================================================
# Prerequisite - boto3
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
# Check Show Script
# ============================================================

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  echo "[ERROR] Step Functions show script not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_stepfunctions.py exists."


# ============================================================
# LocalStack Health Check
# ============================================================

echo
echo "Checking LocalStack..."

if ! command -v curl >/dev/null 2>&1; then
  echo "[WARN] curl is not installed."
  echo "[WARN] Skipping LocalStack HTTP health check."
else
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
fi


# ============================================================
# Step Functions API Check
# ============================================================

echo
echo "Checking Step Functions API..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError

endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

client = boto3.client(
    "stepfunctions",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.list_state_machines(
        maxResults=1,
    )

    status = response.get(
        "ResponseMetadata",
        {},
    ).get(
        "HTTPStatusCode"
    )

    if status != 200:
        print(
            "[ERROR] Unexpected Step Functions "
            f"HTTP status: {status}"
        )
        sys.exit(1)

except (ClientError, BotoCoreError) as error:
    print(
        "[ERROR] Step Functions API check failed: "
        f"{error}"
    )
    sys.exit(1)

print(
    "[PASS] Step Functions API is available."
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
echo "RESOURCE DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"