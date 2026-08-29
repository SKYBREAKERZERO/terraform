#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

PROJECT_ROOT="$(
  cd "${SCRIPT_DIR}/../.."
  pwd
)"

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/sqs/show_sqs.py"


# ============================================================
# Default Environment
# ============================================================

export LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"

export PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
export ENVIRONMENT="${ENVIRONMENT:-localstack}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-test}"

export SQS_FIFO_QUEUE="${SQS_FIFO_QUEUE:-false}"

export SQS_CONTENT_BASED_DEDUPLICATION="${
SQS_CONTENT_BASED_DEDUPLICATION:-false
}"

export SQS_DEAD_LETTER_QUEUE_ENABLED="${
SQS_DEAD_LETTER_QUEUE_ENABLED:-true
}"

export SQS_MAX_RECEIVE_COUNT="${SQS_MAX_RECEIVE_COUNT:-5}"

export SQS_VISIBILITY_TIMEOUT_SECONDS="${
SQS_VISIBILITY_TIMEOUT_SECONDS:-30
}"

export SQS_MESSAGE_RETENTION_SECONDS="${
SQS_MESSAGE_RETENTION_SECONDS:-345600
}"

export SQS_RECEIVE_WAIT_TIME_SECONDS="${
SQS_RECEIVE_WAIT_TIME_SECONDS:-20
}"

export SQS_DELAY_SECONDS="${SQS_DELAY_SECONDS:-0}"

export SQS_MAX_MESSAGE_SIZE="${SQS_MAX_MESSAGE_SIZE:-262144}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Helpers
# ============================================================

separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}


error() {
  echo "[ERROR] $*" >&2
}


# ============================================================
# Header
# ============================================================

separator
echo "SQS SHOW"
separator

echo "Project:           ${PROJECT_NAME}"
echo "Environment:       ${ENVIRONMENT}"
echo "Region:            ${AWS_REGION}"
echo "LocalStack:        ${LOCALSTACK_ENDPOINT}"
echo "FIFO Queue:        ${SQS_FIFO_QUEUE}"
echo "DLQ Enabled:       ${SQS_DEAD_LETTER_QUEUE_ENABLED}"

if [[ -n "${SQS_QUEUE_NAME:-}" ]]; then
  echo "Queue Name:        ${SQS_QUEUE_NAME}"
else
  echo "Queue Name:        auto"
fi

echo


# ============================================================
# Checks
# ============================================================

if ! command -v python3 >/dev/null 2>&1; then
  error "python3 is not installed or not in PATH."
  exit 1
fi

if ! python3 -c "import boto3" >/dev/null 2>&1; then
  error "Python package boto3 is not installed."
  exit 1
fi

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  error "SQS show script not found:"
  error "${SHOW_SCRIPT}"
  exit 1
fi


# ============================================================
# Run
# ============================================================

python3 "${SHOW_SCRIPT}"