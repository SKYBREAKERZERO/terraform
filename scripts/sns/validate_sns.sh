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

VALIDATOR="${PROJECT_ROOT}/python/src/sns/validate_sns.py"


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
export SNS_FIFO_TOPIC="${SNS_FIFO_TOPIC:-false}"
export SNS_CONTENT_BASED_DEDUPLICATION="${SNS_CONTENT_BASED_DEDUPLICATION:-false}"
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
# Pre-check
# ============================================================

separator
echo "SNS VALIDATION"
separator

info "Project:           ${PROJECT_NAME}"
info "Environment:       ${ENVIRONMENT}"
info "Region:            ${AWS_REGION}"
info "LocalStack:        ${LOCALSTACK_ENDPOINT}"
info "FIFO Topic:        ${SNS_FIFO_TOPIC}"
info "Content Dedup:     ${SNS_CONTENT_BASED_DEDUPLICATION}"

if [[ -n "${SNS_TOPIC_NAME:-}" ]]; then
  info "Topic Name:        ${SNS_TOPIC_NAME}"
else
  info "Topic Name:        auto"
fi

if [[ -n "${SNS_KMS_MASTER_KEY_ID:-}" ]]; then
  info "KMS Key:           ${SNS_KMS_MASTER_KEY_ID}"
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
  error "SNS validator not found:"
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
echo "RUNNING SNS VALIDATOR"
separator

python3 "${VALIDATOR}"
exit_code=$?

echo

separator

if [[ ${exit_code} -eq 0 ]]; then
  echo "[PASS] SNS validation completed successfully."
else
  echo "[FAIL] SNS validation failed with exit code ${exit_code}."
fi

separator

exit "${exit_code}"