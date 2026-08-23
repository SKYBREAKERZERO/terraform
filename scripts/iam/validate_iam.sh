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
# IAM Feature Flags
# ============================================================

IAM_ENABLE_SSM="${IAM_ENABLE_SSM:-true}"
IAM_ENABLE_CLOUDWATCH_AGENT="${IAM_ENABLE_CLOUDWATCH_AGENT:-true}"


# ============================================================
# Expected IAM Configuration
# ============================================================

EXPECTED_ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-role"
EXPECTED_ROLE_DESCRIPTION="IAM role for private application EC2 instances"

EXPECTED_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-instance-profile"

EXPECTED_SSM_POLICY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ssm-core"
EXPECTED_CLOUDWATCH_POLICY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cloudwatch-agent"

EXPECTED_TRUST_ACTION="sts:AssumeRole"
EXPECTED_TRUST_PRINCIPAL="ec2.amazonaws.com"

EXPECTED_COMPONENT="identity"
EXPECTED_SERVICE="ec2"
EXPECTED_ROLE_TAG="application"

EXPECTED_MANAGED_BY="terraform"
EXPECTED_DEPLOYMENT="${ENVIRONMENT}"


# ============================================================
# Required SSM Actions
# ============================================================

REQUIRED_SSM_ACTIONS=(
    "ssm:UpdateInstanceInformation"

    "ssmmessages:CreateControlChannel"
    "ssmmessages:CreateDataChannel"
    "ssmmessages:OpenControlChannel"
    "ssmmessages:OpenDataChannel"

    "ec2messages:AcknowledgeMessage"
    "ec2messages:DeleteMessage"
    "ec2messages:FailMessage"
    "ec2messages:GetEndpoint"
    "ec2messages:GetMessages"
    "ec2messages:SendReply"
)


# ============================================================
# Required CloudWatch Agent Actions
# ============================================================

REQUIRED_CLOUDWATCH_ACTIONS=(
    "cloudwatch:PutMetricData"

    "logs:CreateLogGroup"
    "logs:CreateLogStream"
    "logs:DescribeLogGroups"
    "logs:DescribeLogStreams"
    "logs:PutLogEvents"

    "ec2:DescribeTags"
    "ec2:DescribeVolumes"
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
# AWS Helpers
# ============================================================

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


get_role_tag() {
    local tag_name="$1"

    aws_iam list-role-tags \
        --role-name "${ROLE_NAME}" \
        --query "Tags[?Key=='${tag_name}'].Value | [0]" \
        --output text \
        2>/dev/null
}


get_local_policy_arn() {
    local policy_name="$1"

    aws_iam list-policies \
        --scope Local \
        --query \
            "Policies[?PolicyName=='${policy_name}'].Arn | [0]" \
        --output text \
        2>/dev/null
}


get_policy_default_version() {
    local policy_arn="$1"

    aws_iam get-policy \
        --policy-arn "${policy_arn}" \
        --query 'Policy.DefaultVersionId' \
        --output text \
        2>/dev/null
}


get_policy_document() {
    local policy_arn="$1"
    local version_id

    version_id="$(get_policy_default_version "${policy_arn}")"

    if [[ -z "${version_id}" || "${version_id}" == "None" ]]; then
        return 1
    fi

    aws_iam get-policy-version \
        --policy-arn "${policy_arn}" \
        --version-id "${version_id}" \
        --query 'PolicyVersion.Document' \
        --output json \
        2>/dev/null
}


policy_has_action() {
    local policy_document="$1"
    local expected_action="$2"

    printf '%s\n' "${policy_document}" |
        grep -Fq "\"${expected_action}\""
}


# ============================================================
# Pre-flight
# ============================================================

section "PRE-FLIGHT CHECKS"

for command_name in aws terraform curl grep; do

    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Command available: ${command_name}"
    else
        fail "Command not found: ${command_name}"
    fi

done


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

info "SSM policy enabled: ${IAM_ENABLE_SSM}"
info "CloudWatch Agent policy enabled: ${IAM_ENABLE_CLOUDWATCH_AGENT}"


# ============================================================
# Terraform Outputs
# ============================================================

section "TERRAFORM OUTPUTS"

TF_ROLE_NAME="$(terraform_output_raw "ec2_role_name")"
TF_ROLE_ARN="$(terraform_output_raw "ec2_role_arn")"

TF_INSTANCE_PROFILE_NAME="$(
    terraform_output_raw "ec2_instance_profile_name"
)"

TF_SSM_POLICY_ARN="$(
    terraform_output_raw "ssm_policy_arn"
)"

TF_CLOUDWATCH_POLICY_ARN="$(
    terraform_output_raw "cloudwatch_agent_policy_arn"
)"


if [[ -n "${TF_ROLE_NAME}" && "${TF_ROLE_NAME}" != "null" ]]; then

    pass "Terraform ec2_role_name output is available"

    if [[ "${TF_ROLE_NAME}" == "${EXPECTED_ROLE_NAME}" ]]; then
        pass "Terraform role name=${EXPECTED_ROLE_NAME}"
    else
        fail "Terraform role name=${TF_ROLE_NAME}, expected=${EXPECTED_ROLE_NAME}"
    fi

    ROLE_NAME="${TF_ROLE_NAME}"

else

    warn "ec2_role_name Terraform output unavailable; using deterministic name"
    ROLE_NAME="${EXPECTED_ROLE_NAME}"

fi


if [[ -n "${TF_ROLE_ARN}" && "${TF_ROLE_ARN}" != "null" ]]; then
    pass "Terraform ec2_role_arn output is available"
else
    warn "ec2_role_arn Terraform output unavailable"
fi


if [[ -n "${TF_INSTANCE_PROFILE_NAME}" &&
      "${TF_INSTANCE_PROFILE_NAME}" != "null" ]]; then

    pass "Terraform ec2_instance_profile_name output is available"

    if [[ "${TF_INSTANCE_PROFILE_NAME}" == "${EXPECTED_INSTANCE_PROFILE_NAME}" ]]; then
        pass "Terraform instance profile name=${EXPECTED_INSTANCE_PROFILE_NAME}"
    else
        fail "Terraform instance profile=${TF_INSTANCE_PROFILE_NAME}, expected=${EXPECTED_INSTANCE_PROFILE_NAME}"
    fi

    INSTANCE_PROFILE_NAME="${TF_INSTANCE_PROFILE_NAME}"

else

    warn "ec2_instance_profile_name output unavailable; using deterministic name"
    INSTANCE_PROFILE_NAME="${EXPECTED_INSTANCE_PROFILE_NAME}"

fi


# ============================================================
# IAM Role
# ============================================================

section "EC2 IAM ROLE"

ROLE_EXISTS="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.RoleName' \
        --output text \
        2>/dev/null
)"

if [[ "${ROLE_EXISTS}" == "${ROLE_NAME}" ]]; then
    pass "EC2 IAM role exists: ${ROLE_NAME}"
else
    fail "EC2 IAM role not found: ${ROLE_NAME}"

    section "VALIDATION SUMMARY"

    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"

    exit 1
fi


# ============================================================
# Role Description
# ============================================================

ACTUAL_ROLE_DESCRIPTION="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.Description' \
        --output text \
        2>/dev/null
)"

if [[ "${ACTUAL_ROLE_DESCRIPTION}" == "${EXPECTED_ROLE_DESCRIPTION}" ]]; then
    pass "IAM role description is correct"
else
    fail "IAM role description=${ACTUAL_ROLE_DESCRIPTION}, expected=${EXPECTED_ROLE_DESCRIPTION}"
fi


# ============================================================
# Role ARN
# ============================================================

ACTUAL_ROLE_ARN="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.Arn' \
        --output text \
        2>/dev/null
)"

if [[ -n "${ACTUAL_ROLE_ARN}" && "${ACTUAL_ROLE_ARN}" != "None" ]]; then
    pass "IAM role ARN exists: ${ACTUAL_ROLE_ARN}"
else
    fail "IAM role ARN is unavailable"
fi


if [[ -n "${TF_ROLE_ARN}" &&
      "${TF_ROLE_ARN}" != "null" &&
      "${TF_ROLE_ARN}" != "${ACTUAL_ROLE_ARN}" ]]; then

    fail "Terraform role ARN differs from runtime role ARN"
fi


# ============================================================
# Trust Policy
# ============================================================

section "TRUST POLICY"

TRUST_POLICY="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.AssumeRolePolicyDocument' \
        --output json \
        2>/dev/null
)"


if [[ -n "${TRUST_POLICY}" ]]; then
    pass "Trust policy document exists"
else
    fail "Trust policy document is missing"
fi


if printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq "\"${EXPECTED_TRUST_ACTION}\""; then

    pass "Trust policy allows ${EXPECTED_TRUST_ACTION}"
else
    fail "Trust policy does not allow ${EXPECTED_TRUST_ACTION}"
fi


if printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq "\"${EXPECTED_TRUST_PRINCIPAL}\""; then

    pass "Trust principal=${EXPECTED_TRUST_PRINCIPAL}"
else
    fail "Expected EC2 service principal is missing"
fi


if printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq '"Effect": "Allow"'; then

    pass "Trust policy contains Allow statement"
else
    fail "Trust policy does not contain expected Allow statement"
fi


# ============================================================
# Trust Policy Guardrails
# ============================================================

section "TRUST POLICY GUARDRAILS"

if printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq '"AWS": "*"'; then

    fail "Trust policy contains unrestricted AWS principal '*'"
else
    pass "No unrestricted AWS principal in trust policy"
fi


if printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq '"Service": "*"'; then

    fail "Trust policy contains unrestricted service principal '*'"
else
    pass "No unrestricted service principal in trust policy"
fi


# ============================================================
# Role Tags
# ============================================================

section "ROLE TAG VALIDATION"

ACTUAL_PROJECT_TAG="$(get_role_tag "Project")"
ACTUAL_ENVIRONMENT_TAG="$(get_role_tag "Environment")"
ACTUAL_MANAGED_BY_TAG="$(get_role_tag "ManagedBy")"
ACTUAL_DEPLOYMENT_TAG="$(get_role_tag "Deployment")"

ACTUAL_COMPONENT_TAG="$(get_role_tag "Component")"
ACTUAL_SERVICE_TAG="$(get_role_tag "Service")"
ACTUAL_ROLE_TAG="$(get_role_tag "Role")"


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


if [[ "${ACTUAL_ROLE_TAG}" == "${EXPECTED_ROLE_TAG}" ]]; then
    pass "Role tag=${EXPECTED_ROLE_TAG}"
else
    fail "Role tag=${ACTUAL_ROLE_TAG}, expected=${EXPECTED_ROLE_TAG}"
fi


# ============================================================
# Inline Policy Guardrail
# ============================================================

section "INLINE POLICY GUARDRAIL"

INLINE_POLICY_COUNT="$(
    aws_iam list-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'length(PolicyNames)' \
        --output text \
        2>/dev/null
)"

if [[ "${INLINE_POLICY_COUNT}" == "0" ]]; then
    pass "IAM role has no inline policies"
else
    fail "IAM role has ${INLINE_POLICY_COUNT} inline policy/policies"
fi


# ============================================================
# Instance Profile
# ============================================================

section "INSTANCE PROFILE"

PROFILE_EXISTS="$(
    aws_iam get-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --query 'InstanceProfile.InstanceProfileName' \
        --output text \
        2>/dev/null
)"

if [[ "${PROFILE_EXISTS}" == "${INSTANCE_PROFILE_NAME}" ]]; then
    pass "EC2 instance profile exists: ${INSTANCE_PROFILE_NAME}"
else
    fail "EC2 instance profile not found: ${INSTANCE_PROFILE_NAME}"
fi


PROFILE_ROLE_COUNT="$(
    aws_iam get-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --query 'length(InstanceProfile.Roles)' \
        --output text \
        2>/dev/null
)"

if [[ "${PROFILE_ROLE_COUNT}" == "1" ]]; then
    pass "Instance profile contains exactly one IAM role"
else
    fail "Instance profile role count=${PROFILE_ROLE_COUNT}, expected=1"
fi


PROFILE_ROLE_NAME="$(
    aws_iam get-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --query 'InstanceProfile.Roles[0].RoleName' \
        --output text \
        2>/dev/null
)"

if [[ "${PROFILE_ROLE_NAME}" == "${ROLE_NAME}" ]]; then
    pass "Instance profile is associated with EC2 role=${ROLE_NAME}"
else
    fail "Instance profile role=${PROFILE_ROLE_NAME}, expected=${ROLE_NAME}"
fi


# ============================================================
# Role -> Instance Profile Association
# ============================================================

PROFILE_ASSOCIATION_COUNT="$(
    aws_iam list-instance-profiles-for-role \
        --role-name "${ROLE_NAME}" \
        --query \
            "length(InstanceProfiles[?InstanceProfileName=='${INSTANCE_PROFILE_NAME}'])" \
        --output text \
        2>/dev/null
)"

if [[ "${PROFILE_ASSOCIATION_COUNT}" == "1" ]]; then
    pass "Role -> instance profile association exists"
else
    fail "Expected role -> instance profile association is missing"
fi


# ============================================================
# SSM Policy
# ============================================================

section "SSM POLICY"

SSM_POLICY_ARN="$(get_local_policy_arn "${EXPECTED_SSM_POLICY_NAME}")"

if [[ "${IAM_ENABLE_SSM}" == "true" ]]; then

    if [[ -n "${SSM_POLICY_ARN}" && "${SSM_POLICY_ARN}" != "None" ]]; then
        pass "SSM policy exists: ${EXPECTED_SSM_POLICY_NAME}"
    else
        fail "SSM policy not found: ${EXPECTED_SSM_POLICY_NAME}"
    fi


    if [[ -n "${TF_SSM_POLICY_ARN}" &&
          "${TF_SSM_POLICY_ARN}" != "null" &&
          "${TF_SSM_POLICY_ARN}" != "${SSM_POLICY_ARN}" ]]; then

        fail "Terraform SSM policy ARN differs from runtime policy ARN"
    fi


    SSM_ATTACHMENT_COUNT="$(
        aws_iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query \
                "length(AttachedPolicies[?PolicyArn=='${SSM_POLICY_ARN}'])" \
            --output text \
            2>/dev/null
    )"


    if [[ "${SSM_ATTACHMENT_COUNT}" == "1" ]]; then
        pass "SSM policy is attached to EC2 role"
    else
        fail "SSM policy is not attached to EC2 role"
    fi


    SSM_POLICY_DOCUMENT="$(get_policy_document "${SSM_POLICY_ARN}")"

    if [[ -n "${SSM_POLICY_DOCUMENT}" ]]; then
        pass "SSM policy document is readable"
    else
        fail "Unable to read SSM policy document"
    fi


    for required_action in "${REQUIRED_SSM_ACTIONS[@]}"; do

        if policy_has_action \
            "${SSM_POLICY_DOCUMENT}" \
            "${required_action}"; then

            pass "SSM permission present: ${required_action}"
        else
            fail "SSM permission missing: ${required_action}"
        fi

    done


    if printf '%s\n' "${SSM_POLICY_DOCUMENT}" |
        grep -Fq '"Action": "*"'; then

        fail "SSM policy contains Action='*'"
    else
        pass "SSM policy does not contain Action='*'"
    fi

else

    if [[ -z "${SSM_POLICY_ARN}" || "${SSM_POLICY_ARN}" == "None" ]]; then
        pass "SSM policy correctly disabled"
    else
        fail "SSM policy exists although IAM_ENABLE_SSM=false"
    fi

fi


# ============================================================
# CloudWatch Agent Policy
# ============================================================

section "CLOUDWATCH AGENT POLICY"

CLOUDWATCH_POLICY_ARN="$(
    get_local_policy_arn "${EXPECTED_CLOUDWATCH_POLICY_NAME}"
)"

if [[ "${IAM_ENABLE_CLOUDWATCH_AGENT}" == "true" ]]; then

    if [[ -n "${CLOUDWATCH_POLICY_ARN}" &&
          "${CLOUDWATCH_POLICY_ARN}" != "None" ]]; then

        pass "CloudWatch Agent policy exists: ${EXPECTED_CLOUDWATCH_POLICY_NAME}"
    else
        fail "CloudWatch Agent policy not found: ${EXPECTED_CLOUDWATCH_POLICY_NAME}"
    fi


    if [[ -n "${TF_CLOUDWATCH_POLICY_ARN}" &&
          "${TF_CLOUDWATCH_POLICY_ARN}" != "null" &&
          "${TF_CLOUDWATCH_POLICY_ARN}" != "${CLOUDWATCH_POLICY_ARN}" ]]; then

        fail "Terraform CloudWatch policy ARN differs from runtime policy ARN"
    fi


    CLOUDWATCH_ATTACHMENT_COUNT="$(
        aws_iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query \
                "length(AttachedPolicies[?PolicyArn=='${CLOUDWATCH_POLICY_ARN}'])" \
            --output text \
            2>/dev/null
    )"


    if [[ "${CLOUDWATCH_ATTACHMENT_COUNT}" == "1" ]]; then
        pass "CloudWatch Agent policy is attached to EC2 role"
    else
        fail "CloudWatch Agent policy is not attached to EC2 role"
    fi


    CLOUDWATCH_POLICY_DOCUMENT="$(
        get_policy_document "${CLOUDWATCH_POLICY_ARN}"
    )"

    if [[ -n "${CLOUDWATCH_POLICY_DOCUMENT}" ]]; then
        pass "CloudWatch Agent policy document is readable"
    else
        fail "Unable to read CloudWatch Agent policy document"
    fi


    for required_action in "${REQUIRED_CLOUDWATCH_ACTIONS[@]}"; do

        if policy_has_action \
            "${CLOUDWATCH_POLICY_DOCUMENT}" \
            "${required_action}"; then

            pass "CloudWatch permission present: ${required_action}"
        else
            fail "CloudWatch permission missing: ${required_action}"
        fi

    done


    if printf '%s\n' "${CLOUDWATCH_POLICY_DOCUMENT}" |
        grep -Fq '"Action": "*"'; then

        fail "CloudWatch Agent policy contains Action='*'"
    else
        pass "CloudWatch Agent policy does not contain Action='*'"
    fi

else

    if [[ -z "${CLOUDWATCH_POLICY_ARN}" ||
          "${CLOUDWATCH_POLICY_ARN}" == "None" ]]; then

        pass "CloudWatch Agent policy correctly disabled"
    else
        fail "CloudWatch Agent policy exists although IAM_ENABLE_CLOUDWATCH_AGENT=false"
    fi

fi


# ============================================================
# Managed Policy Count
# ============================================================

section "MANAGED POLICY ATTACHMENTS"

ATTACHED_POLICY_COUNT="$(
    aws_iam list-attached-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'length(AttachedPolicies)' \
        --output text \
        2>/dev/null
)"

EXPECTED_POLICY_COUNT=0

if [[ "${IAM_ENABLE_SSM}" == "true" ]]; then
    EXPECTED_POLICY_COUNT=$((EXPECTED_POLICY_COUNT + 1))
fi

if [[ "${IAM_ENABLE_CLOUDWATCH_AGENT}" == "true" ]]; then
    EXPECTED_POLICY_COUNT=$((EXPECTED_POLICY_COUNT + 1))
fi


if [[ "${ATTACHED_POLICY_COUNT}" == "${EXPECTED_POLICY_COUNT}" ]]; then

    pass "Attached managed policy count=${EXPECTED_POLICY_COUNT}"
else

    fail "Attached managed policy count=${ATTACHED_POLICY_COUNT}, expected=${EXPECTED_POLICY_COUNT}"
fi


# ============================================================
# Privilege Guardrails
# ============================================================

section "PRIVILEGE GUARDRAILS"

ATTACHED_POLICY_NAMES="$(
    aws_iam list-attached-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'AttachedPolicies[].PolicyName' \
        --output text \
        2>/dev/null
)"


if [[ " ${ATTACHED_POLICY_NAMES} " == *" AdministratorAccess "* ]]; then

    fail "AdministratorAccess is attached to EC2 role"
else
    pass "AdministratorAccess is not attached"
fi


if [[ " ${ATTACHED_POLICY_NAMES} " == *" PowerUserAccess "* ]]; then

    fail "PowerUserAccess is attached to EC2 role"
else
    pass "PowerUserAccess is not attached"
fi


if [[ " ${ATTACHED_POLICY_NAMES} " == *" IAMFullAccess "* ]]; then

    fail "IAMFullAccess is attached to EC2 role"
else
    pass "IAMFullAccess is not attached"
fi


# ============================================================
# Project IAM Resource Counts
# ============================================================

section "PROJECT IAM RESOURCE VALIDATION"

PROJECT_ROLE_COUNT="$(
    aws_iam list-roles \
        --query \
            "length(Roles[?RoleName=='${EXPECTED_ROLE_NAME}'])" \
        --output text \
        2>/dev/null
)"

if [[ "${PROJECT_ROLE_COUNT}" == "1" ]]; then
    pass "Exactly one project EC2 role exists"
else
    fail "Project EC2 role count=${PROJECT_ROLE_COUNT}, expected=1"
fi


PROJECT_PROFILE_COUNT="$(
    aws_iam list-instance-profiles \
        --query \
            "length(InstanceProfiles[?InstanceProfileName=='${EXPECTED_INSTANCE_PROFILE_NAME}'])" \
        --output text \
        2>/dev/null
)"

if [[ "${PROJECT_PROFILE_COUNT}" == "1" ]]; then
    pass "Exactly one project EC2 instance profile exists"
else
    fail "Project EC2 instance profile count=${PROJECT_PROFILE_COUNT}, expected=1"
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
    echo "[SUCCESS] IAM validation passed."
    exit 0
fi

echo "[FAILED] IAM validation failed."
exit 1