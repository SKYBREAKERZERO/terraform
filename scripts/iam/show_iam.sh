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

EXPECTED_ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-role"
EXPECTED_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-instance-profile"

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

warn() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
}

aws_iam() {
    aws \
        --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        iam "$@"
}


terraform_output_raw() {
    local output_name="$1"

    terraform \
        -chdir="${TF_DIR}" \
        output \
        -raw "${output_name}" \
        2>/dev/null || true
}


# ============================================================
# Pre-flight
# ============================================================

section "IAM INSPECTION"

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

EC2_ROLE_NAME="$(terraform_output_raw "ec2_role_name")"
EC2_ROLE_ARN="$(terraform_output_raw "ec2_role_arn")"

EC2_INSTANCE_PROFILE_NAME="$(
    terraform_output_raw "ec2_instance_profile_name"
)"

SSM_POLICY_ARN="$(
    terraform_output_raw "ssm_policy_arn"
)"

CLOUDWATCH_AGENT_POLICY_ARN="$(
    terraform_output_raw "cloudwatch_agent_policy_arn"
)"


# Fall back to deterministic module naming if root outputs
# have not yet been added.
if [[ -z "${EC2_ROLE_NAME}" || "${EC2_ROLE_NAME}" == "null" ]]; then
    EC2_ROLE_NAME="${EXPECTED_ROLE_NAME}"
    warn "ec2_role_name output unavailable; using expected name: ${EC2_ROLE_NAME}"
else
    echo "EC2_ROLE_NAME=${EC2_ROLE_NAME}"
fi


if [[ -n "${EC2_ROLE_ARN}" && "${EC2_ROLE_ARN}" != "null" ]]; then
    echo "EC2_ROLE_ARN=${EC2_ROLE_ARN}"
else
    echo "EC2_ROLE_ARN=<unavailable>"
fi


if [[ -z "${EC2_INSTANCE_PROFILE_NAME}" ||
      "${EC2_INSTANCE_PROFILE_NAME}" == "null" ]]; then

    EC2_INSTANCE_PROFILE_NAME="${EXPECTED_INSTANCE_PROFILE_NAME}"

    warn "ec2_instance_profile_name output unavailable; using expected name: ${EC2_INSTANCE_PROFILE_NAME}"
else
    echo "EC2_INSTANCE_PROFILE_NAME=${EC2_INSTANCE_PROFILE_NAME}"
fi


if [[ -n "${SSM_POLICY_ARN}" && "${SSM_POLICY_ARN}" != "null" ]]; then
    echo "SSM_POLICY_ARN=${SSM_POLICY_ARN}"
else
    echo "SSM_POLICY_ARN=<disabled or unavailable>"
fi


if [[ -n "${CLOUDWATCH_AGENT_POLICY_ARN}" &&
      "${CLOUDWATCH_AGENT_POLICY_ARN}" != "null" ]]; then

    echo "CLOUDWATCH_AGENT_POLICY_ARN=${CLOUDWATCH_AGENT_POLICY_ARN}"
else
    echo "CLOUDWATCH_AGENT_POLICY_ARN=<disabled or unavailable>"
fi


# ============================================================
# EC2 IAM Role
# ============================================================

section "EC2 IAM ROLE"

if aws_iam get-role \
    --role-name "${EC2_ROLE_NAME}" \
    --output json; then

    :
else
    error "Unable to retrieve IAM role: ${EC2_ROLE_NAME}"
    exit 1
fi


# ============================================================
# Role Summary
# ============================================================

section "ROLE SUMMARY"

aws_iam get-role \
    --role-name "${EC2_ROLE_NAME}" \
    --query \
        'Role.{
            RoleName:RoleName,
            RoleId:RoleId,
            Arn:Arn,
            Path:Path,
            Description:Description,
            CreateDate:CreateDate,
            MaxSessionDuration:MaxSessionDuration
        }' \
    --output table


# ============================================================
# Trust Policy
# ============================================================

section "TRUST POLICY"

aws_iam get-role \
    --role-name "${EC2_ROLE_NAME}" \
    --query 'Role.AssumeRolePolicyDocument' \
    --output json


# ============================================================
# Role Tags
# ============================================================

section "ROLE TAGS"

aws_iam list-role-tags \
    --role-name "${EC2_ROLE_NAME}" \
    --query 'Tags' \
    --output table


# ============================================================
# Attached Managed Policies
# ============================================================

section "ATTACHED MANAGED POLICIES"

ATTACHED_POLICY_ARNS="$(
    aws_iam list-attached-role-policies \
        --role-name "${EC2_ROLE_NAME}" \
        --query 'AttachedPolicies[].PolicyArn' \
        --output text
)"

if [[ -z "${ATTACHED_POLICY_ARNS}" ||
      "${ATTACHED_POLICY_ARNS}" == "None" ]]; then

    info "No managed policies are attached."
else

    aws_iam list-attached-role-policies \
        --role-name "${EC2_ROLE_NAME}" \
        --query \
            'AttachedPolicies[].[
                PolicyName,
                PolicyArn
            ]' \
        --output table
fi


# ============================================================
# Inline Policies
# ============================================================

section "INLINE POLICIES"

INLINE_POLICIES="$(
    aws_iam list-role-policies \
        --role-name "${EC2_ROLE_NAME}" \
        --query 'PolicyNames' \
        --output text
)"

if [[ -z "${INLINE_POLICIES}" ||
      "${INLINE_POLICIES}" == "None" ]]; then

    info "No inline policies are configured."
else

    aws_iam list-role-policies \
        --role-name "${EC2_ROLE_NAME}" \
        --output table
fi


# ============================================================
# Managed Policy Details
# ============================================================

section "MANAGED POLICY DETAILS"

if [[ -n "${ATTACHED_POLICY_ARNS}" &&
      "${ATTACHED_POLICY_ARNS}" != "None" ]]; then

    for policy_arn in ${ATTACHED_POLICY_ARNS}; do

        echo
        info "Policy ARN: ${policy_arn}"

        aws_iam get-policy \
            --policy-arn "${policy_arn}" \
            --query \
                'Policy.{
                    PolicyName:PolicyName,
                    PolicyId:PolicyId,
                    Arn:Arn,
                    DefaultVersionId:DefaultVersionId,
                    AttachmentCount:AttachmentCount,
                    IsAttachable:IsAttachable,
                    CreateDate:CreateDate,
                    UpdateDate:UpdateDate
                }' \
            --output table || {
                warn "Unable to retrieve policy metadata: ${policy_arn}"
                continue
            }

    done
else
    info "No managed policy details to display."
fi


# ============================================================
# Managed Policy Documents
# ============================================================

section "MANAGED POLICY DOCUMENTS"

if [[ -n "${ATTACHED_POLICY_ARNS}" &&
      "${ATTACHED_POLICY_ARNS}" != "None" ]]; then

    for policy_arn in ${ATTACHED_POLICY_ARNS}; do

        echo
        echo "----------------------------------------------------------------------"
        info "Policy: ${policy_arn}"
        echo "----------------------------------------------------------------------"

        DEFAULT_VERSION_ID="$(
            aws_iam get-policy \
                --policy-arn "${policy_arn}" \
                --query 'Policy.DefaultVersionId' \
                --output text \
                2>/dev/null || true
        )"

        if [[ -z "${DEFAULT_VERSION_ID}" ||
              "${DEFAULT_VERSION_ID}" == "None" ]]; then

            warn "Unable to determine default version for ${policy_arn}"
            continue
        fi

        if ! aws_iam get-policy-version \
            --policy-arn "${policy_arn}" \
            --version-id "${DEFAULT_VERSION_ID}" \
            --query 'PolicyVersion.Document' \
            --output json; then

            warn "Unable to retrieve policy document for ${policy_arn}"
        fi

    done
else
    info "No managed policy documents to display."
fi


# ============================================================
# Instance Profile
# ============================================================

section "EC2 INSTANCE PROFILE"

if aws_iam get-instance-profile \
    --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
    --output json; then

    :
else
    error "Unable to retrieve instance profile: ${EC2_INSTANCE_PROFILE_NAME}"
    exit 1
fi


# ============================================================
# Instance Profile Summary
# ============================================================

section "INSTANCE PROFILE SUMMARY"

aws_iam get-instance-profile \
    --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
    --query \
        'InstanceProfile.{
            InstanceProfileName:InstanceProfileName,
            InstanceProfileId:InstanceProfileId,
            Arn:Arn,
            Path:Path,
            CreateDate:CreateDate
        }' \
    --output table


# ============================================================
# Roles in Instance Profile
# ============================================================

section "INSTANCE PROFILE ROLES"

aws_iam get-instance-profile \
    --instance-profile-name "${EC2_INSTANCE_PROFILE_NAME}" \
    --query \
        'InstanceProfile.Roles[].[
            RoleName,
            Arn
        ]' \
    --output table


# ============================================================
# Instance Profiles Attached to Role
# ============================================================

section "INSTANCE PROFILES FOR ROLE"

aws_iam list-instance-profiles-for-role \
    --role-name "${EC2_ROLE_NAME}" \
    --query \
        'InstanceProfiles[].[
            InstanceProfileName,
            Arn
        ]' \
    --output table


# ============================================================
# IAM Resource Overview
# ============================================================

section "PROJECT IAM RESOURCE OVERVIEW"

echo
info "Roles matching project prefix"

aws_iam list-roles \
    --query \
        "Roles[?starts_with(RoleName, '${PROJECT_NAME}-${ENVIRONMENT}')].[RoleName,Arn]" \
    --output table


echo
info "Policies matching project prefix"

aws_iam list-policies \
    --scope Local \
    --query \
        "Policies[?starts_with(PolicyName, '${PROJECT_NAME}-${ENVIRONMENT}')].[PolicyName,Arn,AttachmentCount]" \
    --output table


echo
info "Instance profiles matching project prefix"

aws_iam list-instance-profiles \
    --query \
        "InstanceProfiles[?starts_with(InstanceProfileName, '${PROJECT_NAME}-${ENVIRONMENT}')].[InstanceProfileName,Arn]" \
    --output table


# ============================================================
# Inspection Complete
# ============================================================

section "IAM INSPECTION COMPLETE"

echo "[SUCCESS] IAM inspection completed."