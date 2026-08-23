#!/usr/bin/env bash

set -uo pipefail


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
# Expected Security Configuration
# ============================================================

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

EXPECTED_SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app-sg"
EXPECTED_SECURITY_GROUP_DESCRIPTION="Security group for private application EC2 instances"

EXPECTED_EGRESS_CIDR="0.0.0.0/0"
EXPECTED_EGRESS_PROTOCOL="-1"

EXPECTED_TIER="private-app"
EXPECTED_ROLE="application"
EXPECTED_COMPONENT="security"
EXPECTED_SERVICE="ec2"

EXPECTED_MANAGED_BY="terraform"
EXPECTED_DEPLOYMENT="${ENVIRONMENT}"


# ============================================================
# Counters
# ============================================================

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0


# ============================================================
# Output Helpers
# ============================================================

section() {
    echo
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
}

pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    echo "[WARN] $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo "[INFO] $1"
}


# ============================================================
# Generic Helpers
# ============================================================

check_command() {
    local command_name="$1"

    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Command available: ${command_name}"
        return 0
    fi

    fail "Command not found: ${command_name}"
    return 1
}


aws_ec2() {
    aws \
        --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        ec2 "$@"
}


get_security_group_tag() {
    local tag_name="$1"

    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query "SecurityGroups[0].Tags[?Key=='${tag_name}'].Value | [0]" \
        --output text \
        2>/dev/null
}


# ============================================================
# Pre-flight
# ============================================================

section "PRE-FLIGHT CHECKS"

check_command aws
check_command terraform
check_command curl

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo
    echo "[FAILED] Required commands are missing."
    exit 2
fi


# ============================================================
# LocalStack Health
# ============================================================

section "LOCALSTACK HEALTH"

if curl -fsS "${LOCALSTACK_ENDPOINT}/_localstack/health" >/dev/null 2>&1; then
    pass "LocalStack is reachable: ${LOCALSTACK_ENDPOINT}"
else
    fail "LocalStack is not reachable: ${LOCALSTACK_ENDPOINT}"
fi


# ============================================================
# Terraform Directory
# ============================================================

section "TERRAFORM CONFIGURATION"

if [[ -d "${TF_DIR}" ]]; then
    pass "Terraform directory exists: ${TF_DIR}"
else
    fail "Terraform directory does not exist: ${TF_DIR}"
fi

info "Project: ${PROJECT_NAME}"
info "Environment: ${ENVIRONMENT}"
info "AWS Region: ${AWS_REGION}"
info "Endpoint: ${LOCALSTACK_ENDPOINT}"


# ============================================================
# Terraform Outputs
# ============================================================

section "TERRAFORM OUTPUTS"

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id \
        2>/dev/null
)"

APP_SECURITY_GROUP_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_security_group_id \
        2>/dev/null
)"

if [[ -n "${VPC_ID}" ]]; then
    pass "Terraform VPC ID: ${VPC_ID}"
else
    fail "Unable to read vpc_id from Terraform output"
fi

if [[ -n "${APP_SECURITY_GROUP_ID}" ]]; then
    pass "Terraform application security group ID: ${APP_SECURITY_GROUP_ID}"
else
    fail "Unable to read app_security_group_id from Terraform output"
fi


if [[ -z "${VPC_ID}" || -z "${APP_SECURITY_GROUP_ID}" ]]; then
    section "VALIDATION SUMMARY"

    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"

    exit 1
fi


# ============================================================
# Security Group Existence
# ============================================================

section "APPLICATION SECURITY GROUP"

SECURITY_GROUP_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'length(SecurityGroups)' \
        --output text \
        2>/dev/null
)"

if [[ "${SECURITY_GROUP_COUNT}" == "1" ]]; then
    pass "Application security group exists: ${APP_SECURITY_GROUP_ID}"
else
    fail "Application security group not found: ${APP_SECURITY_GROUP_ID}"

    section "VALIDATION SUMMARY"

    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"

    exit 1
fi


# ============================================================
# Security Group VPC
# ============================================================

ACTUAL_VPC_ID="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].VpcId' \
        --output text \
        2>/dev/null
)"

if [[ "${ACTUAL_VPC_ID}" == "${VPC_ID}" ]]; then
    pass "Security group belongs to project VPC: ${VPC_ID}"
else
    fail "Security group VPC=${ACTUAL_VPC_ID}, expected=${VPC_ID}"
fi


# ============================================================
# Security Group Name
# ============================================================

ACTUAL_SECURITY_GROUP_NAME="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].GroupName' \
        --output text \
        2>/dev/null
)"

if [[ "${ACTUAL_SECURITY_GROUP_NAME}" == "${EXPECTED_SECURITY_GROUP_NAME}" ]]; then
    pass "Security group name=${EXPECTED_SECURITY_GROUP_NAME}"
else
    fail "Security group name=${ACTUAL_SECURITY_GROUP_NAME}, expected=${EXPECTED_SECURITY_GROUP_NAME}"
fi


# ============================================================
# Security Group Description
# ============================================================

ACTUAL_DESCRIPTION="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].Description' \
        --output text \
        2>/dev/null
)"

if [[ "${ACTUAL_DESCRIPTION}" == "${EXPECTED_SECURITY_GROUP_DESCRIPTION}" ]]; then
    pass "Security group description is correct"
else
    fail "Security group description=${ACTUAL_DESCRIPTION}, expected=${EXPECTED_SECURITY_GROUP_DESCRIPTION}"
fi


# ============================================================
# Ingress Validation
# ============================================================

section "INGRESS VALIDATION"

INGRESS_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'length(SecurityGroups[0].IpPermissions)' \
        --output text \
        2>/dev/null
)"

if [[ "${INGRESS_COUNT}" == "0" ]]; then
    pass "Application security group has no ingress rules"
else
    fail "Application security group ingress rule count=${INGRESS_COUNT}, expected=0"

    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'SecurityGroups[0].IpPermissions' \
        --output json \
        2>/dev/null
fi


# ============================================================
# Egress Validation
# ============================================================

section "EGRESS VALIDATION"

EGRESS_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query 'length(SecurityGroups[0].IpPermissionsEgress)' \
        --output text \
        2>/dev/null
)"

if [[ "${EGRESS_COUNT}" == "1" ]]; then
    pass "Application security group has exactly one egress rule"
else
    fail "Application security group egress rule count=${EGRESS_COUNT}, expected=1"
fi


EXPECTED_EGRESS_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query \
        "length(SecurityGroups[0].IpPermissionsEgress[?IpProtocol=='${EXPECTED_EGRESS_PROTOCOL}' && IpRanges[?CidrIp=='${EXPECTED_EGRESS_CIDR}']])" \
        --output text \
        2>/dev/null
)"

if [[ "${EXPECTED_EGRESS_COUNT}" -ge 1 ]]; then
    pass "Expected egress rule exists: protocol=${EXPECTED_EGRESS_PROTOCOL}, cidr=${EXPECTED_EGRESS_CIDR}"
else
    fail "Expected egress rule missing: protocol=${EXPECTED_EGRESS_PROTOCOL}, cidr=${EXPECTED_EGRESS_CIDR}"
fi


# ============================================================
# Dangerous Ingress Guardrails
# ============================================================

section "SECURITY GUARDRAILS"

SSH_WORLD_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query \
        "length(SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`22\` && ToPort==\`22\` && IpRanges[?CidrIp=='0.0.0.0/0']])" \
        --output text \
        2>/dev/null
)"

if [[ "${SSH_WORLD_COUNT}" == "0" ]]; then
    pass "No unrestricted SSH ingress from 0.0.0.0/0"
else
    fail "Unrestricted SSH ingress from 0.0.0.0/0 detected"
fi


HTTP_WORLD_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query \
        "length(SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`80\` && ToPort==\`80\` && IpRanges[?CidrIp=='0.0.0.0/0']])" \
        --output text \
        2>/dev/null
)"

if [[ "${HTTP_WORLD_COUNT}" == "0" ]]; then
    pass "No unrestricted HTTP ingress from 0.0.0.0/0"
else
    fail "Unrestricted HTTP ingress from 0.0.0.0/0 detected"
fi


APP_PORT_WORLD_COUNT="$(
    aws_ec2 describe-security-groups \
        --group-ids "${APP_SECURITY_GROUP_ID}" \
        --query \
        "length(SecurityGroups[0].IpPermissions[?IpProtocol=='tcp' && FromPort==\`8080\` && ToPort==\`8080\` && IpRanges[?CidrIp=='0.0.0.0/0']])" \
        --output text \
        2>/dev/null
)"

if [[ "${APP_PORT_WORLD_COUNT}" == "0" ]]; then
    pass "No unrestricted application ingress on TCP/8080"
else
    fail "Unrestricted application ingress on TCP/8080 detected"
fi


# ============================================================
# Tag Validation
# ============================================================

section "TAG VALIDATION"

ACTUAL_NAME_TAG="$(get_security_group_tag "Name")"
ACTUAL_PROJECT_TAG="$(get_security_group_tag "Project")"
ACTUAL_ENVIRONMENT_TAG="$(get_security_group_tag "Environment")"
ACTUAL_MANAGED_BY_TAG="$(get_security_group_tag "ManagedBy")"
ACTUAL_DEPLOYMENT_TAG="$(get_security_group_tag "Deployment")"

ACTUAL_TIER_TAG="$(get_security_group_tag "Tier")"
ACTUAL_ROLE_TAG="$(get_security_group_tag "Role")"
ACTUAL_COMPONENT_TAG="$(get_security_group_tag "Component")"
ACTUAL_SERVICE_TAG="$(get_security_group_tag "Service")"


if [[ "${ACTUAL_NAME_TAG}" == "${EXPECTED_SECURITY_GROUP_NAME}" ]]; then
    pass "Name tag=${EXPECTED_SECURITY_GROUP_NAME}"
else
    fail "Name tag=${ACTUAL_NAME_TAG}, expected=${EXPECTED_SECURITY_GROUP_NAME}"
fi


if [[ "${ACTUAL_PROJECT_TAG}" == "${PROJECT_NAME}" ]]; then
    pass "Project tag=${PROJECT_NAME}"
else
    fail "Project tag=${ACTUAL_PROJECT_TAG}, expected=${PROJECT_NAME}"
fi


if [[ "${ACTUAL_ENVIRONMENT_TAG}" == "${ENVIRONMENT}" ]]; then
    pass "Environment tag=${ENVIRONMENT}"
else
    fail "Environment tag=${ACTUAL_ENVIRONMENT_TAG}, expected=${ENVIRONMENT}"
fi


if [[ "${ACTUAL_MANAGED_BY_TAG}" == "${EXPECTED_MANAGED_BY}" ]]; then
    pass "ManagedBy tag=${EXPECTED_MANAGED_BY}"
else
    fail "ManagedBy tag=${ACTUAL_MANAGED_BY_TAG}, expected=${EXPECTED_MANAGED_BY}"
fi


if [[ "${ACTUAL_DEPLOYMENT_TAG}" == "${EXPECTED_DEPLOYMENT}" ]]; then
    pass "Deployment tag=${EXPECTED_DEPLOYMENT}"
else
    fail "Deployment tag=${ACTUAL_DEPLOYMENT_TAG}, expected=${EXPECTED_DEPLOYMENT}"
fi


if [[ "${ACTUAL_TIER_TAG}" == "${EXPECTED_TIER}" ]]; then
    pass "Tier tag=${EXPECTED_TIER}"
else
    fail "Tier tag=${ACTUAL_TIER_TAG}, expected=${EXPECTED_TIER}"
fi


if [[ "${ACTUAL_ROLE_TAG}" == "${EXPECTED_ROLE}" ]]; then
    pass "Role tag=${EXPECTED_ROLE}"
else
    fail "Role tag=${ACTUAL_ROLE_TAG}, expected=${EXPECTED_ROLE}"
fi


if [[ "${ACTUAL_COMPONENT_TAG}" == "${EXPECTED_COMPONENT}" ]]; then
    pass "Component tag=${EXPECTED_COMPONENT}"
else
    fail "Component tag=${ACTUAL_COMPONENT_TAG}, expected=${EXPECTED_COMPONENT}"
fi


if [[ "${ACTUAL_SERVICE_TAG}" == "${EXPECTED_SERVICE}" ]]; then
    pass "Service tag=${EXPECTED_SERVICE}"
else
    fail "Service tag=${ACTUAL_SERVICE_TAG}, expected=${EXPECTED_SERVICE}"
fi


# ============================================================
# Default Security Group
# ============================================================

section "VPC DEFAULT SECURITY GROUP"

DEFAULT_SECURITY_GROUP_ID="$(
    aws_ec2 describe-security-groups \
        --filters \
            "Name=vpc-id,Values=${VPC_ID}" \
            "Name=group-name,Values=default" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        2>/dev/null
)"

if [[ -n "${DEFAULT_SECURITY_GROUP_ID}" && "${DEFAULT_SECURITY_GROUP_ID}" != "None" ]]; then
    pass "VPC default security group exists: ${DEFAULT_SECURITY_GROUP_ID}"

    if [[ "${DEFAULT_SECURITY_GROUP_ID}" != "${APP_SECURITY_GROUP_ID}" ]]; then
        pass "Enterprise application SG is separate from the VPC default SG"
    else
        fail "Application security group must not be the VPC default security group"
    fi
else
    warn "Unable to resolve VPC default security group"
fi


# ============================================================
# Validation Summary
# ============================================================

section "VALIDATION SUMMARY"

echo "PASS : ${PASS_COUNT}"
echo "WARN : ${WARN_COUNT}"
echo "FAIL : ${FAIL_COUNT}"

echo

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "[SUCCESS] Security validation passed."
    exit 0
fi

echo "[FAILED] Security validation failed."
exit 1