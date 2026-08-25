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

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

EXPECTED_AMI_ID="${EXPECTED_AMI_ID:-ami-df5de72bdb3b}"
EXPECTED_INSTANCE_TYPE="${EXPECTED_INSTANCE_TYPE:-t3.micro}"

EXPECTED_INSTANCE_COUNT=2

EXPECTED_IAM_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-instance-profile"

LOCALSTACK_USE_DEFAULT_SECURITY_GROUP="${LOCALSTACK_USE_DEFAULT_SECURITY_GROUP:-true}"

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

pass() {
    echo "[PASS]$1"
}

info() {
    echo "[INFO]$1"
}

fail() {
    echo "[FAIL]$1"
    exit 1
}

aws_ec2() {
    aws \
        --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        ec2 "$@"
}

get_instance_value() {
    local instance_id="$1"
    local query="$2"

    aws_ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query "Reservations[0].Instances[0].${query}" \
        --output text
}

get_instance_tag() {
    local instance_id="$1"
    local tag_name="$2"

    aws_ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query \
            "Reservations[0].Instances[0].Tags[?Key=='${tag_name}'].Value | [0]" \
        --output text
}

section "EC2 SMOKE TEST"

info "Project             : ${PROJECT_NAME}"
info "Environment         : ${ENVIRONMENT}"
info "AWS region          : ${AWS_REGION}"
info "LocalStack endpoint : ${LOCALSTACK_ENDPOINT}"

section "PRE-FLIGHT"

command -v aws >/dev/null 2>&1 \
    || fail "aws CLI is not installed"

command -v terraform >/dev/null 2>&1 \
    || fail "terraform is not installed"

command -v curl >/dev/null 2>&1 \
    || fail "curl is not installed"

pass "Required commands are available"


# ============================================================
# LocalStack Health
# ============================================================

section "LOCALSTACK HEALTH"

curl -fsS \
    "${LOCALSTACK_ENDPOINT}/_localstack/health" \
    >/dev/null 2>&1 \
    || fail "LocalStack is not reachable"

pass "LocalStack is reachable"

section "TERRAFORM OUTPUTS"

VPC_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw vpc_id \
        2>/dev/null
)" || fail "Unable to read vpc_id"

APP_SECURITY_GROUP_ID="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw app_security_group_id \
        2>/dev/null
)" || fail "Unable to read app_security_group_id"

IAM_INSTANCE_PROFILE_NAME="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw ec2_instance_profile_name \
        2>/dev/null
)" || fail "Unable to read ec2_instance_profile_name"

[[ -n "${VPC_ID}" ]] \
    || fail "vpc_id is empty"

[[ -n "${APP_SECURITY_GROUP_ID}" ]] \
    || fail "app_security_group_id is empty"

[[ -n "${IAM_INSTANCE_PROFILE_NAME}" ]] \
    || fail "ec2_instance_profile_name is empty"

pass "Terraform outputs are available"

info "VPC_ID=${VPC_ID}"
info "APP_SECURITY_GROUP_ID=${APP_SECURITY_GROUP_ID}"
info "IAM_INSTANCE_PROFILE_NAME=${IAM_INSTANCE_PROFILE_NAME}"

section "EC2 DISCOVERY"

INSTANCE_IDS="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=running" \
        --query \
            'Reservations[].Instances[].InstanceId' \
        --output text
)" || fail "Unable to discover application EC2 instances"

INSTANCE_COUNT="$(wc -w <<< "${INSTANCE_IDS}")"

[[ "${INSTANCE_COUNT}" -eq "${EXPECTED_INSTANCE_COUNT}" ]] \
    || fail "Instance count=${INSTANCE_COUNT}, expected=${EXPECTED_INSTANCE_COUNT}"

pass "Exactly ${EXPECTED_INSTANCE_COUNT} running application instances found"

info "INSTANCE_IDS=${INSTANCE_IDS}"

section "INSTANCE ROLE CHECK"

for subnet_role in app-a app-c; do

    INSTANCE_ID="$(
        aws_ec2 describe-instances \
            --filters \
                "Name=tag:Project,Values=${PROJECT_NAME}" \
                "Name=tag:Environment,Values=${ENVIRONMENT}" \
                "Name=tag:Component,Values=compute" \
                "Name=tag:Role,Values=application" \
                "Name=tag:SubnetRole,Values=${subnet_role}" \
                "Name=instance-state-name,Values=running" \
            --query \
                'Reservations[].Instances[].InstanceId | [0]' \
            --output text
    )"

    [[ -n "${INSTANCE_ID}" && "${INSTANCE_ID}" != "None" ]] \
        || fail "${subnet_role} instance is missing"

    pass "${subnet_role} instance exists: ${INSTANCE_ID}"

    ACTUAL_AMI="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "ImageId"
    )"

    if [[ "${ACTUAL_AMI}" == "${EXPECTED_AMI_ID}" ]]; then
        pass "${subnet_role} AMI is correct"
    else
        fail "${subnet_role} AMI=${ACTUAL_AMI}, expected=${EXPECTED_AMI_ID}"
    fi

    ACTUAL_INSTANCE_TYPE="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "InstanceType"
    )"

    [[ "${ACTUAL_INSTANCE_TYPE}" == "${EXPECTED_INSTANCE_TYPE}" ]] \
        || fail "${subnet_role} type=${ACTUAL_INSTANCE_TYPE}, expected=${EXPECTED_INSTANCE_TYPE}"

    pass "${subnet_role} instance type is correct"

    ACTUAL_VPC_ID="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "VpcId"
    )"

    [[ "${ACTUAL_VPC_ID}" == "${VPC_ID}" ]] \
        || fail "${subnet_role} VPC=${ACTUAL_VPC_ID}, expected=${VPC_ID}"

    pass "${subnet_role} belongs to the project VPC"

    PUBLIC_IP="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "PublicIpAddress"
    )"

    if [[ -z "${PUBLIC_IP}" || "${PUBLIC_IP}" == "None" ]]; then
        pass "${subnet_role} has no public IP"
    else
        fail "${subnet_role} has unexpected public IP=${PUBLIC_IP}"
    fi

    PRIVATE_IP="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "PrivateIpAddress"
    )"

    [[ -n "${PRIVATE_IP}" && "${PRIVATE_IP}" != "None" ]] \
        || fail "${subnet_role} has no private IP"

    pass "${subnet_role} private IP=${PRIVATE_IP}"

    HTTP_TOKENS="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "MetadataOptions.HttpTokens"
    )"

    [[ "${HTTP_TOKENS}" == "required" ]] \
        || fail "${subnet_role} IMDS tokens=${HTTP_TOKENS}, expected=required"

    pass "${subnet_role} IMDSv2 is required"

    IAM_PROFILE_ARN="$(
        get_instance_value \
            "${INSTANCE_ID}" \
            "IamInstanceProfile.Arn"
    )"

    [[ -n "${IAM_PROFILE_ARN}" && "${IAM_PROFILE_ARN}" != "None" ]] \
        || fail "${subnet_role} IAM instance profile is missing"

    [[ "${IAM_PROFILE_ARN}" == *"/${EXPECTED_IAM_INSTANCE_PROFILE_NAME}" ]] \
        || fail "${subnet_role} unexpected IAM profile=${IAM_PROFILE_ARN}"

    pass "${subnet_role} IAM instance profile is correct"

    ATTACHED_SG_IDS="$(
        aws_ec2 describe-instances \
            --instance-ids "${INSTANCE_ID}" \
            --query \
                'Reservations[0].Instances[0].SecurityGroups[].GroupId' \
            --output text
    )"

    [[ -n "${ATTACHED_SG_IDS}" && "${ATTACHED_SG_IDS}" != "None" ]] \
        || fail "${subnet_role} has no security group"

    if [[ "${LOCALSTACK_USE_DEFAULT_SECURITY_GROUP}" == "true" ]]; then

        DEFAULT_SECURITY_GROUP_ID="$(
            aws_ec2 describe-security-groups \
                --filters \
                    "Name=vpc-id,Values=${VPC_ID}" \
                    "Name=group-name,Values=default" \
                --query \
                    'SecurityGroups[0].GroupId' \
                --output text
        )"

        [[ -n "${DEFAULT_SECURITY_GROUP_ID}" &&
            "${DEFAULT_SECURITY_GROUP_ID}" != "None" ]] \
            || fail "Unable to resolve VPC default security group"

        [[ " ${ATTACHED_SG_IDS} " == *" ${DEFAULT_SECURITY_GROUP_ID} "* ]] \
            || fail "${subnet_role} does not use LocalStack default SG"

        pass "${subnet_role} uses LocalStack-compatible default SG"

    else

        [[ " ${ATTACHED_SG_IDS} " == *" ${APP_SECURITY_GROUP_ID} "* ]] \
            || fail "${subnet_role} does not use enterprise application SG"

        pass "${subnet_role} uses enterprise application SG"

    fi

    COMPONENT_TAG="$(
        get_instance_tag \
            "${INSTANCE_ID}" \
            "Component"
    )"

    SUBNET_ROLE_TAG="$(
        get_instance_tag \
            "${INSTANCE_ID}" \
            "SubnetRole"
    )"

    [[ "${COMPONENT_TAG}" == "compute" ]] \
        || fail "${subnet_role} Component tag=${COMPONENT_TAG}, expected=compute"

    [[ "${SUBNET_ROLE_TAG}" == "${subnet_role}" ]] \
        || fail "${subnet_role} SubnetRole tag=${SUBNET_ROLE_TAG}"

    pass "${subnet_role} essential tags are correct"

done

section "MULTI-AZ"

INSTANCE_AZS="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=running" \
        --query \
            'Reservations[].Instances[].Placement.AvailabilityZone' \
        --output text
)"

UNIQUE_AZ_COUNT="$(
    tr '\t' '\n' <<< "${INSTANCE_AZS}" |
        sed '/^$/d' |
        sort -u |
        wc -l
)"

[[ "${UNIQUE_AZ_COUNT}" -eq 2 ]] \
    || fail "Instances span ${UNIQUE_AZ_COUNT} AZ(s), expected=2"

pass "Application EC2 instances span two Availability Zones"

section "PUBLIC IP GUARDRAIL"

PUBLIC_IP_COUNT="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=running" \
        --query \
            'length(Reservations[].Instances[?PublicIpAddress!=null][])' \
        --output text
)"
[[ "${PUBLIC_IP_COUNT}" == "0" ]] \
    || fail "${PUBLIC_IP_COUNT} application instance(s) have public IP addresses"

pass "No application EC2 instance has a public IP"

section "EC2 SMOKE TEST RESULT"
echo "[SUCCESS] EC2 smoke test passed."
