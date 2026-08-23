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
# Helpers
# ============================================================

section() {
    echo
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
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

section "SECURITY INSPECTION"

echo "[INFO] Terraform directory : ${TF_DIR}"
echo "[INFO] AWS region          : ${AWS_REGION}"
echo "[INFO] LocalStack endpoint : ${LOCALSTACK_ENDPOINT}"


if ! command -v aws >/dev/null 2>&1; then
    echo "[ERROR] aws CLI is not installed."
    exit 2
fi

if ! command -v terraform >/dev/null 2>&1; then
    echo "[ERROR] terraform is not installed."
    exit 2
fi


# ============================================================
# Terraform Outputs
# ============================================================

section "TERRAFORM OUTPUTS"

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id
)"

APP_SECURITY_GROUP_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_security_group_id
)"

echo "VPC_ID=${VPC_ID}"
echo "APP_SECURITY_GROUP_ID=${APP_SECURITY_GROUP_ID}"


# ============================================================
# Application Security Group
# ============================================================

section "APPLICATION SECURITY GROUP"

aws_ec2 describe-security-groups \
    --group-ids "${APP_SECURITY_GROUP_ID}" \
    --output table


# ============================================================
# Ingress Rules
# ============================================================

section "APPLICATION SECURITY GROUP - INGRESS"

aws_ec2 describe-security-group-rules \
    --filters \
        "Name=group-id,Values=${APP_SECURITY_GROUP_ID}" \
        "Name=is-egress,Values=false" \
    --output table


# ============================================================
# Egress Rules
# ============================================================

section "APPLICATION SECURITY GROUP - EGRESS"

aws_ec2 describe-security-group-rules \
    --filters \
        "Name=group-id,Values=${APP_SECURITY_GROUP_ID}" \
        "Name=is-egress,Values=true" \
    --output table


# ============================================================
# VPC Security Groups
# ============================================================

section "ALL SECURITY GROUPS IN PROJECT VPC"

aws_ec2 describe-security-groups \
    --filters \
        "Name=vpc-id,Values=${VPC_ID}" \
    --query \
        'SecurityGroups[*].[GroupId,GroupName,Description]' \
    --output table