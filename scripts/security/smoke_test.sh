#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TF_DIR="${TF_DIR:-${REPO_ROOT}/environments/localstack}"


# ============================================================
# AWS / LocalStack
# ============================================================

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
export AWS_REGION
export AWS_PAGER=""


# ============================================================
# Expected Configuration
# ============================================================

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

EXPECTED_SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app-sg"
EXPECTED_EGRESS_CIDR="0.0.0.0/0"


# ============================================================
# Helpers
# ============================================================

info() {
    echo "[INFO] $1"
}

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1"
    exit 1
}

aws_ec2() {
    aws \
        --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        ec2 "$@"
}


# ============================================================
# Pre-flight
# ============================================================

echo "======================================================================"
echo "SECURITY SMOKE TEST"
echo "======================================================================"

command -v aws >/dev/null 2>&1 || fail "aws CLI is not installed"
command -v terraform >/dev/null 2>&1 || fail "terraform is not installed"
command -v curl >/dev/null 2>&1 || fail "curl is not installed"

pass "Required commands are available"


# ============================================================
# LocalStack Health
# ============================================================

if curl -fsS "${LOCALSTACK_ENDPOINT}/_localstack/health" >/dev/null 2>&1; then
    pass "LocalStack is reachable"
else
    fail "LocalStack is not reachable: ${LOCALSTACK_ENDPOINT}"
fi


# ============================================================
# Terraform Outputs
# ============================================================

APP_SECURITY_GROUP_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_security_group_id \
        2>/dev/null
)" || fail "Unable to read app_security_group_id from Terraform output"

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id \
        2>/dev/null
)" || fail "Unable to read vpc_id from Terraform output"

[[ -n "${APP_SECURITY_GROUP_ID}" ]] \
    || fail "app_security_group_id is empty"

[[ -n "${VPC_ID}" ]] \
    || fail "vpc_id is empty"

info "VPC_ID=${VPC_ID}"
info "APP_SECURITY_GROUP_ID=${APP_SECURITY_GROUP_ID}"


# ============================================================
# Security Group API Reachability
# ============================================================

SECURITY_GROUP_JSON="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --output json
)" || fail "Unable to describe application security group"

pass "Application security group is reachable through EC2 API"


# ============================================================
# Security Group Identity
# ============================================================

ACTUAL_GROUP_NAME="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].GroupName' \
        --output text
)"

[[ "${ACTUAL_GROUP_NAME}" == "${EXPECTED_SECURITY_GROUP_NAME}" ]] \
    || fail "SG name=${ACTUAL_GROUP_NAME}, expected=${EXPECTED_SECURITY_GROUP_NAME}"

pass "Security group name is correct"


# ============================================================
# VPC Association
# ============================================================

ACTUAL_VPC_ID="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].VpcId' \
        --output text
)"

[[ "${ACTUAL_VPC_ID}" == "${VPC_ID}" ]] \
    || fail "SG VPC=${ACTUAL_VPC_ID}, expected=${VPC_ID}"

pass "Security group belongs to the project VPC"


# ============================================================
# Ingress Smoke Check
# ============================================================

INGRESS_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'length(SecurityGroups[0].IpPermissions)' \
        --output text
)"

[[ "${INGRESS_COUNT}" == "0" ]] \
    || fail "Unexpected ingress rules detected: count=${INGRESS_COUNT}"

pass "No ingress rules are configured"


# ============================================================
# Egress Smoke Check
# ============================================================

EGRESS_MATCH_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query \
        "length(SecurityGroups[0].IpPermissionsEgress[?IpProtocol=='-1' && IpRanges[?CidrIp=='${EXPECTED_EGRESS_CIDR}']])" \
        --output text
)"

[[ "${EGRESS_MATCH_COUNT}" -ge 1 ]] \
    || fail "Expected outbound rule ${EXPECTED_EGRESS_CIDR} was not found"

pass "Expected outbound rule exists"


# ============================================================
# Tag Smoke Check
# ============================================================

COMPONENT_TAG="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query "SecurityGroups[0].Tags[?Key=='Component'].Value | [0]" \
        --output text
)"

[[ "${COMPONENT_TAG}" == "security" ]] \
    || fail "Component tag=${COMPONENT_TAG}, expected=security"

pass "Component tag is correct"


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "SECURITY SMOKE TEST RESULT"
echo "======================================================================"
echo "[SUCCESS] Security smoke test passed."