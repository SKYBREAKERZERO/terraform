#!/usr/bin/env bash

set -u
set -o pipefail


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

VALIDATOR="${PROJECT_ROOT}/python/src/sqs/validate_sqs.py"


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
export SQS_CONTENT_BASED_DEDUPLICATION="${SQS_CONTENT_BASED_DEDUPLICATION:-false}"

export SQS_DEAD_LETTER_QUEUE_ENABLED="${SQS_DEAD_LETTER_QUEUE_ENABLED:-true}"
export SQS_MAX_RECEIVE_COUNT="${SQS_MAX_RECEIVE_COUNT:-5}"

export SQS_VISIBILITY_TIMEOUT_SECONDS="${SQS_VISIBILITY_TIMEOUT_SECONDS:-30}"
export SQS_MESSAGE_RETENTION_SECONDS="${SQS_MESSAGE_RETENTION_SECONDS:-345600}"
export SQS_RECEIVE_WAIT_TIME_SECONDS="${SQS_RECEIVE_WAIT_TIME_SECONDS:-20}"
export SQS_DELAY_SECONDS="${SQS_DELAY_SECONDS:-0}"
export SQS_MAX_MESSAGE_SIZE="${SQS_MAX_MESSAGE_SIZE:-262144}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Output Helpers
# ============================================================

separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}


info() {
  echo "[INFO] $*"
}


error() {
  echo "[ERROR] $*" >&2
}


# ============================================================
# Header
# ============================================================

separator
echo "SQS VALIDATION"
separator

info "Project:           ${PROJECT_NAME}"
info "Environment:       ${ENVIRONMENT}"
info "Region:            ${AWS_REGION}"
info "LocalStack:        ${LOCALSTACK_ENDPOINT}"

info "FIFO Queue:        ${SQS_FIFO_QUEUE}"
info "Content Dedup:     ${SQS_CONTENT_BASED_DEDUPLICATION}"

info "DLQ Enabled:       ${SQS_DEAD_LETTER_QUEUE_ENABLED}"
info "Max Receive Count: ${SQS_MAX_RECEIVE_COUNT}"

info "Visibility:        ${SQS_VISIBILITY_TIMEOUT_SECONDS}"
info "Retention:         ${SQS_MESSAGE_RETENTION_SECONDS}"
info "Long Polling:      ${SQS_RECEIVE_WAIT_TIME_SECONDS}"
info "Delay:             ${SQS_DELAY_SECONDS}"
info "Max Message Size:  ${SQS_MAX_MESSAGE_SIZE}"

if [[ -n "${SQS_QUEUE_NAME:-}" ]]; then
  info "Queue Name:        ${SQS_QUEUE_NAME}"
else
  info "Queue Name:        auto"
fi

if [[ -n "${SQS_KMS_MASTER_KEY_ID:-}" ]]; then
  info "KMS Key:           ${SQS_KMS_MASTER_KEY_ID}"
else
  info "KMS Key:           disabled"
fi

echo


# ============================================================
# Validate Python
# ============================================================

if ! command -v python3 >/dev/null 2>&1; then
  error "python3 is not installed or not in PATH."
  exit 1
fi

info "Python: $(python3 --version 2>&1)"

if ! python3 -c "import boto3" >/dev/null 2>&1; then
  error "Python package boto3 is not installed."
  exit 1
fi

info "boto3 is installed."


# ============================================================
# Validate Script
# ============================================================

if [[ ! -f "${VALIDATOR}" ]]; then
  error "SQS validator not found:"
  error "${VALIDATOR}"
  exit 1
fi

info "Validator: ${VALIDATOR}"

echo


# ============================================================
# LocalStack Connectivity
# ============================================================

if command -v curl >/dev/null 2>&1; then
  if curl \
    --silent \
    --fail \
    --max-time 3 \
    "${LOCALSTACK_ENDPOINT}/_localstack/health" \
    >/dev/null; then

    info "LocalStack is reachable."

  else
    error "LocalStack is not reachable: ${LOCALSTACK_ENDPOINT}"
    exit 1
  fi
else
  info "curl not found; skipping LocalStack connectivity check."
fi

echo


# ============================================================
# Run Validation
# ============================================================

separator
echo "RUNNING SQS VALIDATOR"
separator

python3 "${VALIDATOR}"
exit_code=$?

echo

separator

if [[ ${exit_code} -eq 0 ]]; then
  echo "[PASS] SQS validation completed successfully."
else
  echo "[FAIL] SQS validation failed with exit code ${exit_code}."
fi

separator

exit "${exit_code}"