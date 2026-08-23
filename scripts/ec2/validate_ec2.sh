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

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
export AWS_REGION
export AWS_PAGER=""


# ============================================================
# Expected EC2 Configuration
# ============================================================

EXPECTED_INSTANCE_COUNT=2

EXPECTED_AMI_ID="${EXPECTED_AMI_ID:-ami-df5de72bdb3b}"
EXPECTED_INSTANCE_TYPE="${EXPECTED_INSTANCE_TYPE:-t3.micro}"

EXPECTED_ROOT_VOLUME_TYPE="${EXPECTED_ROOT_VOLUME_TYPE:-gp3}"
EXPECTED_ROOT_VOLUME_SIZE="${EXPECTED_ROOT_VOLUME_SIZE:-20}"

EXPECTED_METADATA_HTTP_TOKENS="required"
EXPECTED_METADATA_HTTP_ENDPOINT="enabled"
EXPECTED_METADATA_HOP_LIMIT="1"

EXPECTED_IAM_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-instance-profile"

EXPECTED_COMPONENT="compute"
EXPECTED_SERVICE="ec2"
EXPECTED_TIER="private-app"
EXPECTED_ROLE="application"

EXPECTED_MANAGED_BY="terraform"
EXPECTED_DEPLOYMENT="${ENVIRONMENT}"

# LocalStack Docker EC2 compatibility mode.
#
# true:
#   EC2 may use the VPC default SG while the enterprise application
#   SG is created and validated independently.
#
# false:
#   EC2 must use module.security application SG.
#
LOCALSTACK_USE_DEFAULT_SECURITY_GROUP="${
    LOCALSTACK_USE_DEFAULT_SECURITY_GROUP:-true
}"


# ============================================================
# Expected Instance Placement
# ============================================================

declare -A EXPECTED_INSTANCE_AZS=(
    ["app-a"]="ap-northeast-1a"
    ["app-c"]="ap-northeast-1c"
)

declare -A EXPECTED_INSTANCE_NAMES=(
    ["app-a"]="${PROJECT_NAME}-${ENVIRONMENT}-app-a-ec2"
    ["app-c"]="${PROJECT_NAME}-${ENVIRONMENT}-app-c-ec2"
)


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


get_instance_value() {
    local instance_id="$1"
    local query="$2"

    aws_ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query "Reservations[0].Instances[0].${query}" \
        --output text \
        2>/dev/null
}


get_instance_tag() {
    local instance_id="$1"
    local tag_name="$2"

    aws_ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query \
            "Reservations[0].Instances[0].Tags[?Key=='${tag_name}'].Value | [0]" \
        --output text \
        2>/dev/null
}


get_instance_id_by_subnet_role() {
    local subnet_role="$1"

    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=tag:SubnetRole,Values=${subnet_role}" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[].InstanceId | [0]' \
        --output text \
        2>/dev/null
}


get_expected_subnet_id() {
    local subnet_role="$1"

    aws_ec2 describe-subnets \
        --filters \
            "Name=vpc-id,Values=${VPC_ID}" \
            "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-${subnet_role}" \
            "Name=tag:Tier,Values=private-app" \
        --query 'Subnets[0].SubnetId' \
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
# Terraform Configuration
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
info "Expected AMI: ${EXPECTED_AMI_ID}"
info "Expected instance type: ${EXPECTED_INSTANCE_TYPE}"


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

IAM_INSTANCE_PROFILE_NAME="$(
    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw ec2_instance_profile_name \
        2>/dev/null
)"

if [[ -n "${VPC_ID}" ]]; then
    pass "Terraform VPC ID: ${VPC_ID}"
else
    fail "Unable to read vpc_id from Terraform output"
fi

if [[ -n "${APP_SECURITY_GROUP_ID}" ]]; then
    pass "Terraform application SG: ${APP_SECURITY_GROUP_ID}"
else
    fail "Unable to read app_security_group_id from Terraform output"
fi

if [[ -n "${IAM_INSTANCE_PROFILE_NAME}" ]]; then
    pass "Terraform EC2 instance profile: ${IAM_INSTANCE_PROFILE_NAME}"
else
    fail "Unable to read ec2_instance_profile_name from Terraform output"
fi


if [[ -z "${VPC_ID}" ]]; then
    section "VALIDATION SUMMARY"

    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"

    exit 1
fi


# ============================================================
# EC2 Discovery
# ============================================================

section "EC2 DISCOVERY"

INSTANCE_IDS="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        2>/dev/null
)"

INSTANCE_COUNT="$(wc -w <<< "${INSTANCE_IDS}")"

if [[ "${INSTANCE_COUNT}" -eq "${EXPECTED_INSTANCE_COUNT}" ]]; then
    pass "Application EC2 instance count=${INSTANCE_COUNT}"
else
    fail "Application EC2 instance count=${INSTANCE_COUNT}, expected=${EXPECTED_INSTANCE_COUNT}"
fi

info "Instances: ${INSTANCE_IDS}"


# ============================================================
# Expected Instance Roles
# ============================================================

section "INSTANCE ROLE VALIDATION"

for subnet_role in app-a app-c; do

    instance_id="$(get_instance_id_by_subnet_role "${subnet_role}")"

    if [[ -n "${instance_id}" && "${instance_id}" != "None" ]]; then
        pass "${subnet_role} instance exists: ${instance_id}"
    else
        fail "${subnet_role} instance is missing"
        continue
    fi


    # ========================================================
    # Name
    # ========================================================

    actual_name="$(get_instance_tag "${instance_id}" "Name")"
    expected_name="${EXPECTED_INSTANCE_NAMES[${subnet_role}]}"

    if [[ "${actual_name}" == "${expected_name}" ]]; then
        pass "${subnet_role} Name=${expected_name}"
    else
        fail "${subnet_role} Name=${actual_name}, expected=${expected_name}"
    fi


    # ========================================================
    # State
    # ========================================================

    instance_state="$(get_instance_value "${instance_id}" "State.Name")"

    if [[ "${instance_state}" == "running" ]]; then
        pass "${subnet_role} state=running"
    else
        fail "${subnet_role} state=${instance_state}, expected=running"
    fi


    # ========================================================
    # AMI
    # ========================================================

    actual_ami="$(get_instance_value "${instance_id}" "ImageId")"

    if [[ "${actual_ami}" == "${EXPECTED_AMI_ID}" ]]; then
        pass "${subnet_role} AMI=${EXPECTED_AMI_ID}"
    else
        fail "${subnet_role} AMI=${actual_ami}, expected=${EXPECTED_AMI_ID}"
    fi


    # ========================================================
    # Instance Type
    # ========================================================

    actual_instance_type="$(get_instance_value "${instance_id}" "InstanceType")"

    if [[ "${actual_instance_type}" == "${EXPECTED_INSTANCE_TYPE}" ]]; then
        pass "${subnet_role} instance type=${EXPECTED_INSTANCE_TYPE}"
    else
        fail "${subnet_role} instance type=${actual_instance_type}, expected=${EXPECTED_INSTANCE_TYPE}"
    fi


    # ========================================================
    # VPC
    # ========================================================

    actual_vpc_id="$(get_instance_value "${instance_id}" "VpcId")"

    if [[ "${actual_vpc_id}" == "${VPC_ID}" ]]; then
        pass "${subnet_role} belongs to project VPC"
    else
        fail "${subnet_role} VPC=${actual_vpc_id}, expected=${VPC_ID}"
    fi


    # ========================================================
    # Availability Zone
    # ========================================================

    actual_az="$(get_instance_value "${instance_id}" "Placement.AvailabilityZone")"
    expected_az="${EXPECTED_INSTANCE_AZS[${subnet_role}]}"

    if [[ "${actual_az}" == "${expected_az}" ]]; then
        pass "${subnet_role} AZ=${expected_az}"
    else
        fail "${subnet_role} AZ=${actual_az}, expected=${expected_az}"
    fi


    # ========================================================
    # Subnet
    # ========================================================

    actual_subnet_id="$(get_instance_value "${instance_id}" "SubnetId")"
    expected_subnet_id="$(get_expected_subnet_id "${subnet_role}")"

    if [[ -z "${expected_subnet_id}" || "${expected_subnet_id}" == "None" ]]; then
        fail "Unable to resolve expected subnet for ${subnet_role}"
    elif [[ "${actual_subnet_id}" == "${expected_subnet_id}" ]]; then
        pass "${subnet_role} deployed in expected private application subnet"
    else
        fail "${subnet_role} subnet=${actual_subnet_id}, expected=${expected_subnet_id}"
    fi


    # ========================================================
    # Private IP
    # ========================================================

    private_ip="$(get_instance_value "${instance_id}" "PrivateIpAddress")"

    if [[ -n "${private_ip}" && "${private_ip}" != "None" ]]; then
        pass "${subnet_role} private IP=${private_ip}"
    else
        fail "${subnet_role} has no private IP"
    fi


    # ========================================================
    # Public IP Guardrail
    # ========================================================

    public_ip="$(get_instance_value "${instance_id}" "PublicIpAddress")"

    if [[ -z "${public_ip}" || "${public_ip}" == "None" ]]; then
        pass "${subnet_role} has no public IP"
    else
        fail "${subnet_role} public IP detected: ${public_ip}"
    fi


    # ========================================================
    # Source / Destination Check
    # ========================================================

    source_dest_check="$(get_instance_value "${instance_id}" "SourceDestCheck")"

    if [[ "${source_dest_check}" == "True" || "${source_dest_check}" == "true" ]]; then
        pass "${subnet_role} SourceDestCheck=true"
    else
        fail "${subnet_role} SourceDestCheck=${source_dest_check}, expected=true"
    fi


    # ========================================================
    # IMDSv2
    # ========================================================

    section "IMDS VALIDATION - ${subnet_role}"

    metadata_endpoint="$(
        get_instance_value \
            "${instance_id}" \
            "MetadataOptions.HttpEndpoint"
    )"

    metadata_tokens="$(
        get_instance_value \
            "${instance_id}" \
            "MetadataOptions.HttpTokens"
    )"

    metadata_hop_limit="$(
        get_instance_value \
            "${instance_id}" \
            "MetadataOptions.HttpPutResponseHopLimit"
    )"

    metadata_tags="$(
        get_instance_value \
            "${instance_id}" \
            "MetadataOptions.InstanceMetadataTags"
    )"


    if [[ "${metadata_endpoint}" == "${EXPECTED_METADATA_HTTP_ENDPOINT}" ]]; then
        pass "${subnet_role} IMDS endpoint=enabled"
    else
        fail "${subnet_role} IMDS endpoint=${metadata_endpoint}, expected=enabled"
    fi


    if [[ "${metadata_tokens}" == "${EXPECTED_METADATA_HTTP_TOKENS}" ]]; then
        pass "${subnet_role} IMDSv2 tokens=required"
    else
        fail "${subnet_role} IMDS tokens=${metadata_tokens}, expected=required"
    fi


    if [[ "${metadata_hop_limit}" == "${EXPECTED_METADATA_HOP_LIMIT}" ]]; then
        pass "${subnet_role} IMDS hop limit=${EXPECTED_METADATA_HOP_LIMIT}"
    else
        fail "${subnet_role} IMDS hop limit=${metadata_hop_limit}, expected=${EXPECTED_METADATA_HOP_LIMIT}"
    fi


    if [[ "${metadata_tags}" == "enabled" ]]; then
        pass "${subnet_role} instance metadata tags=enabled"
    else
        warn "${subnet_role} instance metadata tags=${metadata_tags}, expected=enabled"
    fi


    # ========================================================
    # IAM Instance Profile
    # ========================================================

    section "IAM VALIDATION - ${subnet_role}"

    iam_profile_arn="$(
        get_instance_value \
            "${instance_id}" \
            "IamInstanceProfile.Arn"
    )"

    if [[ -n "${iam_profile_arn}" && "${iam_profile_arn}" != "None" ]]; then
        pass "${subnet_role} IAM instance profile attached"

        if [[ "${iam_profile_arn}" == *"/${EXPECTED_IAM_INSTANCE_PROFILE_NAME}" ]]; then
            pass "${subnet_role} IAM profile=${EXPECTED_IAM_INSTANCE_PROFILE_NAME}"
        else
            fail "${subnet_role} IAM profile ARN=${iam_profile_arn}, expected profile=${EXPECTED_IAM_INSTANCE_PROFILE_NAME}"
        fi
    else
        fail "${subnet_role} IAM instance profile is not attached"
    fi


    # ========================================================
    # Security Groups
    # ========================================================

    section "SECURITY GROUP VALIDATION - ${subnet_role}"

    attached_sg_ids="$(
        aws_ec2 describe-instances \
            --instance-ids "${instance_id}" \
            --query \
                'Reservations[0].Instances[0].SecurityGroups[].GroupId' \
            --output text \
            2>/dev/null
    )"

    if [[ -n "${attached_sg_ids}" && "${attached_sg_ids}" != "None" ]]; then
        pass "${subnet_role} has security group attachment"
    else
        fail "${subnet_role} has no security group attachment"
    fi


    if [[ "${LOCALSTACK_USE_DEFAULT_SECURITY_GROUP}" == "true" ]]; then

        default_sg_id="$(
            aws_ec2 describe-security-groups \
                --filters \
                    "Name=vpc-id,Values=${VPC_ID}" \
                    "Name=group-name,Values=default" \
                --query 'SecurityGroups[0].GroupId' \
                --output text \
                2>/dev/null
        )"

        if [[ " ${attached_sg_ids} " == *" ${default_sg_id} "* ]]; then
            pass "${subnet_role} uses LocalStack-compatible default SG=${default_sg_id}"
        else
            fail "${subnet_role} does not use expected LocalStack default SG=${default_sg_id}"
        fi

    else

        if [[ " ${attached_sg_ids} " == *" ${APP_SECURITY_GROUP_ID} "* ]]; then
            pass "${subnet_role} uses enterprise application SG=${APP_SECURITY_GROUP_ID}"
        else
            fail "${subnet_role} does not use enterprise application SG=${APP_SECURITY_GROUP_ID}"
        fi

    fi


    # ========================================================
    # Root EBS
    # ========================================================

    section "EBS VALIDATION - ${subnet_role}"

    root_device_name="$(
        get_instance_value \
            "${instance_id}" \
            "RootDeviceName"
    )"

    root_volume_id="$(
        aws_ec2 describe-instances \
            --instance-ids "${instance_id}" \
            --query \
                "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='${root_device_name}'].Ebs.VolumeId | [0]" \
            --output text \
            2>/dev/null
    )"


    if [[ -n "${root_volume_id}" && "${root_volume_id}" != "None" ]]; then
        pass "${subnet_role} root EBS volume=${root_volume_id}"
    else
        fail "${subnet_role} root EBS volume not found"
    fi


    if [[ -n "${root_volume_id}" && "${root_volume_id}" != "None" ]]; then

        volume_type="$(
            aws_ec2 describe-volumes \
                --volume-ids "${root_volume_id}" \
                --query 'Volumes[0].VolumeType' \
                --output text \
                2>/dev/null
        )"

        volume_size="$(
            aws_ec2 describe-volumes \
                --volume-ids "${root_volume_id}" \
                --query 'Volumes[0].Size' \
                --output text \
                2>/dev/null
        )"

        volume_encrypted="$(
            aws_ec2 describe-volumes \
                --volume-ids "${root_volume_id}" \
                --query 'Volumes[0].Encrypted' \
                --output text \
                2>/dev/null
        )"


        if [[ "${volume_type}" == "${EXPECTED_ROOT_VOLUME_TYPE}" ]]; then
            pass "${subnet_role} root EBS type=${EXPECTED_ROOT_VOLUME_TYPE}"
        else
            fail "${subnet_role} root EBS type=${volume_type}, expected=${EXPECTED_ROOT_VOLUME_TYPE}"
        fi


        if [[ "${volume_size}" == "${EXPECTED_ROOT_VOLUME_SIZE}" ]]; then
            pass "${subnet_role} root EBS size=${EXPECTED_ROOT_VOLUME_SIZE} GiB"
        else
            fail "${subnet_role} root EBS size=${volume_size}, expected=${EXPECTED_ROOT_VOLUME_SIZE} GiB"
        fi


        if [[ "${volume_encrypted}" == "True" || "${volume_encrypted}" == "true" ]]; then
            pass "${subnet_role} root EBS encrypted=true"
        else
            fail "${subnet_role} root EBS encrypted=${volume_encrypted}, expected=true"
        fi

    fi


    # ========================================================
    # Tags
    # ========================================================

    section "TAG VALIDATION - ${subnet_role}"

    project_tag="$(get_instance_tag "${instance_id}" "Project")"
    environment_tag="$(get_instance_tag "${instance_id}" "Environment")"
    managed_by_tag="$(get_instance_tag "${instance_id}" "ManagedBy")"
    deployment_tag="$(get_instance_tag "${instance_id}" "Deployment")"

    component_tag="$(get_instance_tag "${instance_id}" "Component")"
    service_tag="$(get_instance_tag "${instance_id}" "Service")"
    tier_tag="$(get_instance_tag "${instance_id}" "Tier")"
    role_tag="$(get_instance_tag "${instance_id}" "Role")"
    subnet_role_tag="$(get_instance_tag "${instance_id}" "SubnetRole")"


    if [[ "${project_tag}" == "${PROJECT_NAME}" ]]; then
        pass "${subnet_role} Project tag=${PROJECT_NAME}"
    else
        fail "${subnet_role} Project tag=${project_tag}, expected=${PROJECT_NAME}"
    fi


    if [[ "${environment_tag}" == "${ENVIRONMENT}" ]]; then
        pass "${subnet_role} Environment tag=${ENVIRONMENT}"
    else
        fail "${subnet_role} Environment tag=${environment_tag}, expected=${ENVIRONMENT}"
    fi


    if [[ "${managed_by_tag}" == "${EXPECTED_MANAGED_BY}" ]]; then
        pass "${subnet_role} ManagedBy tag=${EXPECTED_MANAGED_BY}"
    else
        fail "${subnet_role} ManagedBy tag=${managed_by_tag}, expected=${EXPECTED_MANAGED_BY}"
    fi


    if [[ "${deployment_tag}" == "${EXPECTED_DEPLOYMENT}" ]]; then
        pass "${subnet_role} Deployment tag=${EXPECTED_DEPLOYMENT}"
    else
        fail "${subnet_role} Deployment tag=${deployment_tag}, expected=${EXPECTED_DEPLOYMENT}"
    fi


    if [[ "${component_tag}" == "${EXPECTED_COMPONENT}" ]]; then
        pass "${subnet_role} Component tag=${EXPECTED_COMPONENT}"
    else
        fail "${subnet_role} Component tag=${component_tag}, expected=${EXPECTED_COMPONENT}"
    fi


    if [[ "${service_tag}" == "${EXPECTED_SERVICE}" ]]; then
        pass "${subnet_role} Service tag=${EXPECTED_SERVICE}"
    else
        fail "${subnet_role} Service tag=${service_tag}, expected=${EXPECTED_SERVICE}"
    fi


    if [[ "${tier_tag}" == "${EXPECTED_TIER}" ]]; then
        pass "${subnet_role} Tier tag=${EXPECTED_TIER}"
    else
        fail "${subnet_role} Tier tag=${tier_tag}, expected=${EXPECTED_TIER}"
    fi


    if [[ "${role_tag}" == "${EXPECTED_ROLE}" ]]; then
        pass "${subnet_role} Role tag=${EXPECTED_ROLE}"
    else
        fail "${subnet_role} Role tag=${role_tag}, expected=${EXPECTED_ROLE}"
    fi


    if [[ "${subnet_role_tag}" == "${subnet_role}" ]]; then
        pass "${subnet_role} SubnetRole tag=${subnet_role}"
    else
        fail "${subnet_role} SubnetRole tag=${subnet_role_tag}, expected=${subnet_role}"
    fi

done


# ============================================================
# Multi-AZ Guardrail
# ============================================================

section "MULTI-AZ VALIDATION"

INSTANCE_AZS="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[].Placement.AvailabilityZone' \
        --output text \
        2>/dev/null
)"

UNIQUE_AZ_COUNT="$(
    tr '\t' '\n' <<< "${INSTANCE_AZS}" |
        sed '/^$/d' |
        sort -u |
        wc -l
)"

if [[ "${UNIQUE_AZ_COUNT}" -eq 2 ]]; then
    pass "Application instances span two Availability Zones"
else
    fail "Application instances span ${UNIQUE_AZ_COUNT} Availability Zone(s), expected=2"
fi


# ============================================================
# Public IP Global Guardrail
# ============================================================

section "PUBLIC IP GUARDRAIL"

PUBLIC_IP_COUNT="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
        --query \
            'length(Reservations[].Instances[?PublicIpAddress!=null][])' \
        --output text \
        2>/dev/null
)"

if [[ "${PUBLIC_IP_COUNT}" == "0" ]]; then
    pass "No application EC2 instance has a public IP"
else
    fail "${PUBLIC_IP_COUNT} application EC2 instance(s) have public IP addresses"
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
    echo "[SUCCESS] EC2 validation passed."
    exit 0
fi

echo "[FAILED] EC2 validation failed."
exit 1