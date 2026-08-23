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

info() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1"
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

section "EC2 INSPECTION"

info "Repository root     : ${REPO_ROOT}"
info "Terraform directory : ${TF_DIR}"
info "Project             : ${PROJECT_NAME}"
info "Environment         : ${ENVIRONMENT}"
info "AWS region          : ${AWS_REGION}"
info "LocalStack endpoint : ${LOCALSTACK_ENDPOINT}"

if ! command -v aws >/dev/null 2>&1; then
    error "aws CLI is not installed."
    exit 2
fi

if ! command -v terraform >/dev/null 2>&1; then
    error "terraform is not installed."
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    error "curl is not installed."
    exit 2
fi


# ============================================================
# LocalStack Health
# ============================================================

section "LOCALSTACK HEALTH"

if curl -fsS "${LOCALSTACK_ENDPOINT}/_localstack/health" >/dev/null 2>&1; then
    info "LocalStack is reachable."
else
    error "LocalStack is not reachable: ${LOCALSTACK_ENDPOINT}"
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
        -raw vpc_id \
        2>/dev/null || true
)"

if [[ -n "${VPC_ID}" ]]; then
    echo "VPC_ID=${VPC_ID}"
else
    echo "VPC_ID=<unavailable>"
fi


if terraform \
    -chdir="${TF_DIR}" \
    output \
    ec2_instance_ids >/dev/null 2>&1; then

    echo
    echo "EC2_INSTANCE_IDS:"

    terraform \
        -chdir="${TF_DIR}" \
        output \
        -json ec2_instance_ids
else
    echo
    echo "EC2_INSTANCE_IDS=<output not defined>"
fi


if terraform \
    -chdir="${TF_DIR}" \
    output \
    ec2_private_ips >/dev/null 2>&1; then

    echo
    echo "EC2_PRIVATE_IPS:"

    terraform \
        -chdir="${TF_DIR}" \
        output \
        -json ec2_private_ips
else
    echo
    echo "EC2_PRIVATE_IPS=<output not defined>"
fi


if terraform \
    -chdir="${TF_DIR}" \
    output \
    ec2_availability_zones >/dev/null 2>&1; then

    echo
    echo "EC2_AVAILABILITY_ZONES:"

    terraform \
        -chdir="${TF_DIR}" \
        output \
        -json ec2_availability_zones
fi


# ============================================================
# Discover Application EC2 Instances
# ============================================================

section "APPLICATION EC2 DISCOVERY"

INSTANCE_IDS="$(
    aws_ec2 describe-instances \
        --filters \
            "Name=tag:Project,Values=${PROJECT_NAME}" \
            "Name=tag:Environment,Values=${ENVIRONMENT}" \
            "Name=tag:Component,Values=compute" \
            "Name=tag:Role,Values=application" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
)"

if [[ -z "${INSTANCE_IDS}" || "${INSTANCE_IDS}" == "None" ]]; then
    info "No application EC2 instances found."
    exit 0
fi

info "Application EC2 instances: ${INSTANCE_IDS}"


# ============================================================
# Instance Summary
# ============================================================

section "EC2 INSTANCE SUMMARY"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            Tags[?Key==`Name`].Value | [0],
            InstanceType,
            State.Name,
            Placement.AvailabilityZone,
            PrivateIpAddress,
            PublicIpAddress,
            SubnetId,
            VpcId
        ]' \
    --output table


# ============================================================
# AMI / Platform
# ============================================================

section "AMI / PLATFORM"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            ImageId,
            Architecture,
            RootDeviceType,
            RootDeviceName
        ]' \
    --output table


# ============================================================
# Network
# ============================================================

section "NETWORK"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            SubnetId,
            VpcId,
            Placement.AvailabilityZone,
            PrivateIpAddress,
            PublicIpAddress,
            SourceDestCheck
        ]' \
    --output table


# ============================================================
# Security Groups
# ============================================================

section "SECURITY GROUPS"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].{
            InstanceId: InstanceId,
            Name: Tags[?Key==`Name`].Value | [0],
            SecurityGroups: SecurityGroups
        }' \
    --output json


# ============================================================
# IAM Instance Profile
# ============================================================

section "IAM INSTANCE PROFILE"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            IamInstanceProfile.Arn,
            IamInstanceProfile.Id
        ]' \
    --output table


# ============================================================
# Instance Metadata Service
# ============================================================

section "INSTANCE METADATA SERVICE"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            MetadataOptions.HttpEndpoint,
            MetadataOptions.HttpTokens,
            MetadataOptions.HttpPutResponseHopLimit,
            MetadataOptions.InstanceMetadataTags
        ]' \
    --output table


# ============================================================
# Monitoring / EBS Optimization
# ============================================================

section "MONITORING / PERFORMANCE"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].[
            InstanceId,
            Monitoring.State,
            EbsOptimized
        ]' \
    --output table


# ============================================================
# Block Device Mapping
# ============================================================

section "BLOCK DEVICE MAPPING"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].{
            InstanceId: InstanceId,
            RootDeviceName: RootDeviceName,
            BlockDevices: BlockDeviceMappings
        }' \
    --output json


# ============================================================
# EBS Volumes
# ============================================================

section "EBS VOLUMES"

for instance_id in ${INSTANCE_IDS}; do

    info "Instance: ${instance_id}"

    VOLUME_IDS="$(
        aws_ec2 describe-instances \
            --instance-ids "${instance_id}" \
            --query \
                'Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId' \
            --output text
    )"

    if [[ -z "${VOLUME_IDS}" || "${VOLUME_IDS}" == "None" ]]; then
        info "No EBS volumes found."
        continue
    fi

    aws_ec2 describe-volumes \
        --volume-ids ${VOLUME_IDS} \
        --query \
            'Volumes[].[
                VolumeId,
                Size,
                VolumeType,
                Encrypted,
                State,
                AvailabilityZone
            ]' \
        --output table

done


# ============================================================
# Instance Status
# ============================================================

section "INSTANCE STATUS"

aws_ec2 describe-instance-status \
    --instance-ids ${INSTANCE_IDS} \
    --include-all-instances \
    --query \
        'InstanceStatuses[].[
            InstanceId,
            InstanceState.Name,
            SystemStatus.Status,
            InstanceStatus.Status
        ]' \
    --output table


# ============================================================
# Network Interfaces
# ============================================================

section "NETWORK INTERFACES"

aws_ec2 describe-instances \
    --instance-ids ${INSTANCE_IDS} \
    --query \
        'Reservations[].Instances[].{
            InstanceId: InstanceId,
            Interfaces: NetworkInterfaces[].{
                NetworkInterfaceId: NetworkInterfaceId,
                SubnetId: SubnetId,
                PrivateIpAddress: PrivateIpAddress,
                PublicIp: Association.PublicIp,
                Status: Status,
                Groups: Groups
            }
        }' \
    --output json


# ============================================================
# Instance Tags
# ============================================================

section "INSTANCE TAGS"

for instance_id in ${INSTANCE_IDS}; do

    info "Instance: ${instance_id}"

    aws_ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query \
            'Reservations[0].Instances[0].Tags' \
        --output table

done


# ============================================================
# Inspection Complete
# ============================================================

section "EC2 INSPECTION COMPLETE"

echo "[SUCCESS] EC2 inspection completed."