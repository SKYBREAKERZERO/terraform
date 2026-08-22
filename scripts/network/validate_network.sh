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
# Expected Network
# ============================================================

EXPECTED_VPC_CIDR="10.0.0.0/16"

EXPECTED_PUBLIC_SUBNETS=(
    "10.0.1.0/24"
    "10.0.2.0/24"
)

EXPECTED_PRIVATE_APP_SUBNETS=(
    "10.0.101.0/24"
    "10.0.102.0/24"
)

EXPECTED_PRIVATE_DB_SUBNETS=(
    "10.0.201.0/24"
    "10.0.202.0/24"
)

EXPECTED_PUBLIC_SUBNET_COUNT=2
EXPECTED_PRIVATE_APP_SUBNET_COUNT=2
EXPECTED_PRIVATE_DB_SUBNET_COUNT=2

EXPECTED_NAT_GATEWAY_COUNT="${EXPECTED_NAT_GATEWAY_COUNT:-1}"

REQUIRE_S3_ENDPOINT="${REQUIRE_S3_ENDPOINT:-true}"
REQUIRE_CUSTOM_NACLS="${REQUIRE_CUSTOM_NACLS:-false}"
REQUIRE_FLOW_LOGS="${REQUIRE_FLOW_LOGS:-false}"


# ============================================================
# Counters
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0


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

fail() {
    echo "[FAIL] $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo "[WARN] $1"
    WARN_COUNT=$((WARN_COUNT + 1))
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


get_subnet_ids_by_tier() {
    local tier="$1"

    aws_ec2 describe-subnets \
        --filters \
            "Name=vpc-id,Values=${VPC_ID}" \
            "Name=tag:Tier,Values=${tier}" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null
}


get_route_table_id() {
    local subnet_id="$1"

    aws_ec2 describe-route-tables \
        --filters \
            "Name=association.subnet-id,Values=${subnet_id}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null
}


get_default_route_igw() {
    local route_table_id="$1"

    aws_ec2 describe-route-tables \
        --route-table-ids "${route_table_id}" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]" \
        --output text 2>/dev/null
}


get_default_route_nat() {
    local route_table_id="$1"

    aws_ec2 describe-route-tables \
        --route-table-ids "${route_table_id}" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId | [0]" \
        --output text 2>/dev/null
}


has_default_route() {
    local route_table_id="$1"
    local route_count

    route_count="$(
        aws_ec2 describe-route-tables \
            --route-table-ids "${route_table_id}" \
            --query "length(RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'])" \
            --output text 2>/dev/null
    )"

    [[ "${route_count}" != "0" ]]
}


check_expected_cidr() {
    local tier="$1"
    local cidr="$2"
    local subnet_id

    subnet_id="$(
        aws_ec2 describe-subnets \
            --filters \
                "Name=vpc-id,Values=${VPC_ID}" \
                "Name=cidr-block,Values=${cidr}" \
                "Name=tag:Tier,Values=${tier}" \
            --query 'Subnets[0].SubnetId' \
            --output text 2>/dev/null
    )"

    if [[ -n "${subnet_id}" && "${subnet_id}" != "None" ]]; then
        pass "${tier} subnet exists: ${cidr} (${subnet_id})"
    else
        fail "${tier} subnet missing: ${cidr}"
    fi
}


# ============================================================
# Preflight
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
# Terraform Output
# ============================================================

section "TERRAFORM OUTPUT"

if [[ -d "${TF_DIR}" ]]; then
    pass "Terraform directory exists: ${TF_DIR}"
else
    fail "Terraform directory does not exist: ${TF_DIR}"
fi

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id \
        2>/dev/null
)"

if [[ -z "${VPC_ID}" ]]; then
    fail "Unable to read vpc_id from Terraform output"

    section "VALIDATION SUMMARY"
    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"

    exit 1
fi

pass "Terraform VPC ID: ${VPC_ID}"

info "AWS Region: ${AWS_REGION}"
info "Endpoint: ${LOCALSTACK_ENDPOINT}"


# ============================================================
# VPC
# ============================================================

section "VPC VALIDATION"

ACTUAL_VPC_CIDR="$(
    aws_ec2 describe-vpcs \
        --vpc-ids "${VPC_ID}" \
        --query 'Vpcs[0].CidrBlock' \
        --output text 2>/dev/null
)"

ACTUAL_VPC_STATE="$(
    aws_ec2 describe-vpcs \
        --vpc-ids "${VPC_ID}" \
        --query 'Vpcs[0].State' \
        --output text 2>/dev/null
)"

if [[ "${ACTUAL_VPC_CIDR}" == "${EXPECTED_VPC_CIDR}" ]]; then
    pass "VPC CIDR=${EXPECTED_VPC_CIDR}"
else
    fail "VPC CIDR=${ACTUAL_VPC_CIDR}, expected=${EXPECTED_VPC_CIDR}"
fi

if [[ "${ACTUAL_VPC_STATE}" == "available" ]]; then
    pass "VPC state=available"
else
    fail "VPC state=${ACTUAL_VPC_STATE}, expected=available"
fi


# ============================================================
# DNS
# ============================================================

section "VPC DNS VALIDATION"

DNS_SUPPORT="$(
    aws_ec2 describe-vpc-attribute \
        --vpc-id "${VPC_ID}" \
        --attribute enableDnsSupport \
        --query 'EnableDnsSupport.Value' \
        --output text 2>/dev/null
)"

DNS_HOSTNAMES="$(
    aws_ec2 describe-vpc-attribute \
        --vpc-id "${VPC_ID}" \
        --attribute enableDnsHostnames \
        --query 'EnableDnsHostnames.Value' \
        --output text 2>/dev/null
)"

if [[ "${DNS_SUPPORT}" == "True" || "${DNS_SUPPORT}" == "true" ]]; then
    pass "VPC DNS support enabled"
else
    fail "VPC DNS support=${DNS_SUPPORT}, expected=true"
fi

if [[ "${DNS_HOSTNAMES}" == "True" || "${DNS_HOSTNAMES}" == "true" ]]; then
    pass "VPC DNS hostnames enabled"
else
    fail "VPC DNS hostnames=${DNS_HOSTNAMES}, expected=true"
fi


# ============================================================
# Subnets
# ============================================================

section "SUBNET VALIDATION"

PUBLIC_SUBNET_IDS="$(get_subnet_ids_by_tier "public")"
PRIVATE_APP_SUBNET_IDS="$(get_subnet_ids_by_tier "private-app")"
PRIVATE_DB_SUBNET_IDS="$(get_subnet_ids_by_tier "private-db")"

PUBLIC_COUNT="$(wc -w <<< "${PUBLIC_SUBNET_IDS}")"
APP_COUNT="$(wc -w <<< "${PRIVATE_APP_SUBNET_IDS}")"
DB_COUNT="$(wc -w <<< "${PRIVATE_DB_SUBNET_IDS}")"

if [[ "${PUBLIC_COUNT}" -eq "${EXPECTED_PUBLIC_SUBNET_COUNT}" ]]; then
    pass "Public subnet count=${PUBLIC_COUNT}"
else
    fail "Public subnet count=${PUBLIC_COUNT}, expected=${EXPECTED_PUBLIC_SUBNET_COUNT}"
fi

if [[ "${APP_COUNT}" -eq "${EXPECTED_PRIVATE_APP_SUBNET_COUNT}" ]]; then
    pass "Private app subnet count=${APP_COUNT}"
else
    fail "Private app subnet count=${APP_COUNT}, expected=${EXPECTED_PRIVATE_APP_SUBNET_COUNT}"
fi

if [[ "${DB_COUNT}" -eq "${EXPECTED_PRIVATE_DB_SUBNET_COUNT}" ]]; then
    pass "Private DB subnet count=${DB_COUNT}"
else
    fail "Private DB subnet count=${DB_COUNT}, expected=${EXPECTED_PRIVATE_DB_SUBNET_COUNT}"
fi

for cidr in "${EXPECTED_PUBLIC_SUBNETS[@]}"; do
    check_expected_cidr "public" "${cidr}"
done

for cidr in "${EXPECTED_PRIVATE_APP_SUBNETS[@]}"; do
    check_expected_cidr "private-app" "${cidr}"
done

for cidr in "${EXPECTED_PRIVATE_DB_SUBNETS[@]}"; do
    check_expected_cidr "private-db" "${cidr}"
done


# ============================================================
# Public IP Settings
# ============================================================

section "SUBNET PUBLIC IP VALIDATION"

for subnet_id in ${PUBLIC_SUBNET_IDS}; do
    value="$(
        aws_ec2 describe-subnets \
            --subnet-ids "${subnet_id}" \
            --query 'Subnets[0].MapPublicIpOnLaunch' \
            --output text
    )"

    if [[ "${value}" == "True" || "${value}" == "true" ]]; then
        pass "${subnet_id} MapPublicIpOnLaunch=true"
    else
        fail "${subnet_id} MapPublicIpOnLaunch=${value}, expected=true"
    fi
done

for subnet_id in ${PRIVATE_APP_SUBNET_IDS} ${PRIVATE_DB_SUBNET_IDS}; do
    value="$(
        aws_ec2 describe-subnets \
            --subnet-ids "${subnet_id}" \
            --query 'Subnets[0].MapPublicIpOnLaunch' \
            --output text
    )"

    if [[ "${value}" == "False" || "${value}" == "false" ]]; then
        pass "${subnet_id} MapPublicIpOnLaunch=false"
    else
        fail "${subnet_id} MapPublicIpOnLaunch=${value}, expected=false"
    fi
done


# ============================================================
# IGW
# ============================================================

section "INTERNET GATEWAY VALIDATION"

IGW_IDS="$(
    aws_ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text
)"

IGW_COUNT="$(wc -w <<< "${IGW_IDS}")"

if [[ "${IGW_COUNT}" -eq 1 ]]; then
    IGW_ID="${IGW_IDS}"
    pass "Exactly one IGW attached: ${IGW_ID}"
else
    IGW_ID=""
    fail "Expected 1 IGW, found ${IGW_COUNT}"
fi


# ============================================================
# NAT
# ============================================================

section "NAT GATEWAY VALIDATION"

NAT_IDS="$(
    aws_ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${VPC_ID}" \
        --query "NatGateways[?State!='deleted'].NatGatewayId" \
        --output text
)"

NAT_COUNT="$(wc -w <<< "${NAT_IDS}")"

if [[ "${NAT_COUNT}" -eq "${EXPECTED_NAT_GATEWAY_COUNT}" ]]; then
    pass "NAT Gateway count=${NAT_COUNT}"
else
    fail "NAT Gateway count=${NAT_COUNT}, expected=${EXPECTED_NAT_GATEWAY_COUNT}"
fi

NAT_ID=""

if [[ "${NAT_COUNT}" -gt 0 ]]; then
    NAT_ID="$(awk '{print $1}' <<< "${NAT_IDS}")"

    NAT_STATE="$(
        aws_ec2 describe-nat-gateways \
            --nat-gateway-ids "${NAT_ID}" \
            --query 'NatGateways[0].State' \
            --output text
    )"

    if [[ "${NAT_STATE}" == "available" ]]; then
        pass "NAT Gateway ${NAT_ID} state=available"
    else
        fail "NAT Gateway ${NAT_ID} state=${NAT_STATE}"
    fi
fi


# ============================================================
# Public Routes
# ============================================================

section "PUBLIC ROUTE VALIDATION"

for subnet_id in ${PUBLIC_SUBNET_IDS}; do
    route_table_id="$(get_route_table_id "${subnet_id}")"

    if [[ -z "${route_table_id}" || "${route_table_id}" == "None" ]]; then
        fail "${subnet_id} has no explicit route table association"
        continue
    fi

    pass "${subnet_id} associated with ${route_table_id}"

    gateway_id="$(get_default_route_igw "${route_table_id}")"

    if [[ "${gateway_id}" == "${IGW_ID}" ]]; then
        pass "${subnet_id} 0.0.0.0/0 -> ${IGW_ID}"
    else
        fail "${subnet_id} default route=${gateway_id}, expected=${IGW_ID}"
    fi
done


# ============================================================
# Private App Routes
# ============================================================

section "PRIVATE APPLICATION ROUTE VALIDATION"

for subnet_id in ${PRIVATE_APP_SUBNET_IDS}; do
    route_table_id="$(get_route_table_id "${subnet_id}")"

    if [[ -z "${route_table_id}" || "${route_table_id}" == "None" ]]; then
        fail "${subnet_id} has no explicit route table association"
        continue
    fi

    pass "${subnet_id} associated with ${route_table_id}"

    nat_gateway_id="$(get_default_route_nat "${route_table_id}")"

    if [[ "${nat_gateway_id}" == "${NAT_ID}" ]]; then
        pass "${subnet_id} 0.0.0.0/0 -> ${NAT_ID}"
    else
        fail "${subnet_id} NAT=${nat_gateway_id}, expected=${NAT_ID}"
    fi
done


# ============================================================
# Private DB Isolation
# ============================================================

section "PRIVATE DATABASE ROUTE VALIDATION"

for subnet_id in ${PRIVATE_DB_SUBNET_IDS}; do
    route_table_id="$(get_route_table_id "${subnet_id}")"

    if [[ -z "${route_table_id}" || "${route_table_id}" == "None" ]]; then
        fail "${subnet_id} has no explicit route table association"
        continue
    fi

    pass "${subnet_id} associated with ${route_table_id}"

    if has_default_route "${route_table_id}"; then
        fail "${subnet_id} has unexpected 0.0.0.0/0 route"
    else
        pass "${subnet_id} has no Internet default route"
    fi
done


# ============================================================
# S3 Gateway Endpoint
# ============================================================

section "S3 VPC ENDPOINT VALIDATION"

if [[ "${REQUIRE_S3_ENDPOINT}" == "true" ]]; then
    S3_SERVICE_NAME="com.amazonaws.${AWS_REGION}.s3"

    S3_ENDPOINT_IDS="$(
        aws_ec2 describe-vpc-endpoints \
            --filters \
                "Name=vpc-id,Values=${VPC_ID}" \
                "Name=service-name,Values=${S3_SERVICE_NAME}" \
            --query 'VpcEndpoints[].VpcEndpointId' \
            --output text
    )"

    ENDPOINT_COUNT="$(wc -w <<< "${S3_ENDPOINT_IDS}")"

    if [[ "${ENDPOINT_COUNT}" -eq 1 ]]; then
        S3_ENDPOINT_ID="${S3_ENDPOINT_IDS}"

        pass "S3 VPC Endpoint exists: ${S3_ENDPOINT_ID}"

        ENDPOINT_TYPE="$(
            aws_ec2 describe-vpc-endpoints \
                --vpc-endpoint-ids "${S3_ENDPOINT_ID}" \
                --query 'VpcEndpoints[0].VpcEndpointType' \
                --output text
        )"

        ENDPOINT_STATE="$(
            aws_ec2 describe-vpc-endpoints \
                --vpc-endpoint-ids "${S3_ENDPOINT_ID}" \
                --query 'VpcEndpoints[0].State' \
                --output text
        )"

        if [[ "${ENDPOINT_TYPE}" == "Gateway" ]]; then
            pass "S3 Endpoint type=Gateway"
        else
            fail "S3 Endpoint type=${ENDPOINT_TYPE}, expected=Gateway"
        fi

        if [[ "${ENDPOINT_STATE}" == "available" ]]; then
            pass "S3 Endpoint state=available"
        else
            fail "S3 Endpoint state=${ENDPOINT_STATE}, expected=available"
        fi
    else
        fail "Expected 1 S3 VPC Endpoint, found ${ENDPOINT_COUNT}"
    fi
else
    warn "S3 VPC Endpoint validation disabled"
fi


# ============================================================
# Optional NACL
# ============================================================

section "NETWORK ACL VALIDATION"

if [[ "${REQUIRE_CUSTOM_NACLS}" == "true" ]]; then
    CUSTOM_NACL_COUNT="$(
        aws_ec2 describe-network-acls \
            --filters "Name=vpc-id,Values=${VPC_ID}" \
            --query 'length(NetworkAcls[?IsDefault==`false`])' \
            --output text
    )"

    if [[ "${CUSTOM_NACL_COUNT}" -gt 0 ]]; then
        pass "Custom Network ACL count=${CUSTOM_NACL_COUNT}"
    else
        fail "No custom Network ACLs found"
    fi
else
    warn "Custom Network ACL validation disabled"
fi


# ============================================================
# Optional Flow Logs
# ============================================================

section "VPC FLOW LOG VALIDATION"

if [[ "${REQUIRE_FLOW_LOGS}" == "true" ]]; then
    FLOW_LOG_COUNT="$(
        aws_ec2 describe-flow-logs \
            --filter "Name=resource-id,Values=${VPC_ID}" \
            --query 'length(FlowLogs)' \
            --output text
    )"

    if [[ "${FLOW_LOG_COUNT}" -gt 0 ]]; then
        pass "VPC Flow Log count=${FLOW_LOG_COUNT}"
    else
        fail "No VPC Flow Logs found"
    fi
else
    warn "VPC Flow Log validation disabled"
fi


# ============================================================
# Summary
# ============================================================

section "VALIDATION SUMMARY"

echo "PASS : ${PASS_COUNT}"
echo "WARN : ${WARN_COUNT}"
echo "FAIL : ${FAIL_COUNT}"
echo

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "======================================================================"
    echo "NETWORK VALIDATION PASSED"
    echo "======================================================================"
    exit 0
fi

echo "======================================================================"
echo "NETWORK VALIDATION FAILED"
echo "======================================================================"
exit 1
