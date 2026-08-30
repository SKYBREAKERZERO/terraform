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

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/eventbridge/show_eventbridge.py"


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

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Helpers
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
echo "EVENTBRIDGE SHOW"
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

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  error "EventBridge show script not found:"
  error "${SHOW_SCRIPT}"
  exit 1
fi

info "Show Script: ${SHOW_SCRIPT}"

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
# Run
# ============================================================

separator
echo "EVENTBRIDGE RESOURCES"
separator

python3 "${SHOW_SCRIPT}"