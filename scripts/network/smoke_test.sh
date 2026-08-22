#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${TF_DIR:-${REPO_ROOT}/environments/localstack}"

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
export AWS_REGION
export AWS_PAGER=""

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "[PASS] $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

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
# Start
# ============================================================

section "NETWORK SMOKE TEST"

echo "[INFO] Endpoint: ${LOCALSTACK_ENDPOINT}"
echo "[INFO] Region:   ${AWS_REGION}"
echo "[INFO] TF Dir:   ${TF_DIR}"


# ============================================================
# 1. LocalStack
# ============================================================

section "LOCALSTACK"

if curl -fsS "${LOCALSTACK_ENDPOINT}/_localstack/health" >/dev/null 2>&1; then
    pass "LocalStack health endpoint reachable"
else
    fail "LocalStack health endpoint unreachable"
fi


# ============================================================
# 2. EC2 API
# ============================================================

section "EC2 API"

if aws_ec2 describe-vpcs >/dev/null 2>&1; then
    pass "EC2 API reachable"
else
    fail "EC2 API unreachable"
fi


# ============================================================
# 3. Terraform VPC
# ============================================================

section "PROJECT VPC"

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id \
        2>/dev/null
)"

if [[ -z "${VPC_ID}" ]]; then
    fail "Unable to obtain VPC ID from Terraform"
else
    pass "Terraform returned VPC ID: ${VPC_ID}"
fi


VPC_STATE="$(
    aws_ec2 describe-vpcs \
        --vpc-ids "${VPC_ID}" \
        --query 'Vpcs[0].State' \
        --output text 2>/dev/null
)"

if [[ "${VPC_STATE}" == "available" ]]; then
    pass "Project VPC is available"
else
    fail "Project VPC state=${VPC_STATE}"
fi


# ============================================================
# 4. NAT Gateway
# ============================================================

section "NAT GATEWAY"

NAT_ID="$(
    aws_ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${VPC_ID}" \
        --query "NatGateways[?State=='available'] | [0].NatGatewayId" \
        --output text 2>/dev/null
)"

if [[ -n "${NAT_ID}" && "${NAT_ID}" != "None" ]]; then
    pass "Available NAT Gateway found: ${NAT_ID}"
else
    fail "No available NAT Gateway found"
fi


# ============================================================
# 5. Public Route
# ============================================================

section "PUBLIC INTERNET ROUTE"

IGW_ROUTE_COUNT="$(
    aws_ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query "length(RouteTables[].Routes[?DestinationCidrBlock=='0.0.0.0/0' && GatewayId!=null] | [])" \
        --output text 2>/dev/null
)"

if [[ "${IGW_ROUTE_COUNT}" -gt 0 ]]; then
    pass "Public Internet route exists"
else
    fail "Public Internet route not found"
fi


# ============================================================
# 6. S3 Gateway Endpoint
# ============================================================

section "S3 GATEWAY ENDPOINT"

S3_ENDPOINT_ID="$(
    aws_ec2 describe-vpc-endpoints \
        --filters \
            "Name=vpc-id,Values=${VPC_ID}" \
            "Name=service-name,Values=com.amazonaws.${AWS_REGION}.s3" \
        --query "VpcEndpoints[?State=='available'] | [0].VpcEndpointId" \
        --output text 2>/dev/null
)"

if [[ -n "${S3_ENDPOINT_ID}" && "${S3_ENDPOINT_ID}" != "None" ]]; then
    pass "S3 Gateway Endpoint available: ${S3_ENDPOINT_ID}"
else
    fail "S3 Gateway Endpoint unavailable"
fi


# ============================================================
# Summary
# ============================================================

section "SMOKE TEST SUMMARY"

echo "PASS : ${PASS_COUNT}"
echo "FAIL : ${FAIL_COUNT}"
echo

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "======================================================================"
    echo "[SUCCESS] Network smoke test passed."
    echo "======================================================================"
    exit 0
fi

echo "======================================================================"
echo "[FAILED] Network smoke test failed."
echo "======================================================================"

exit 1
