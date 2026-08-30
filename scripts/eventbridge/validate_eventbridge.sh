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

VALIDATOR="${PROJECT_ROOT}/python/src/eventbridge/validate_eventbridge.py"


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

export EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS="${EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS:-true}"

export EVENTBRIDGE_RULES_JSON="${EVENTBRIDGE_RULES_JSON:-{}}"
export EVENTBRIDGE_TARGETS_JSON="${EVENTBRIDGE_TARGETS_JSON:-{}}"

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
echo "EVENTBRIDGE VALIDATION"
separator

info "Project:           ${PROJECT_NAME}"
info "Environment:       ${ENVIRONMENT}"
info "Region:            ${AWS_REGION}"
info "LocalStack:        ${LOCALSTACK_ENDPOINT}"
info "Custom Event Bus:  ${EVENTBRIDGE_CREATE_CUSTOM_EVENT_BUS}"

if [[ -n "${EVENTBRIDGE_EVENT_BUS_NAME:-}" ]]; then
  info "Event Bus Name:    ${EVENTBRIDGE_EVENT_BUS_NAME}"
else
  info "Event Bus Name:    auto"
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
  error "EventBridge validator not found:"
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
echo "RUNNING EVENTBRIDGE VALIDATOR"
separator

python3 "${VALIDATOR}"
exit_code=$?

echo

separator

if [[ ${exit_code} -eq 0 ]]; then
  echo "[PASS] EventBridge validation completed successfully."
else
  echo "[FAIL] EventBridge validation failed with exit code ${exit_code}."
fi

separator

exit "${exit_code}"