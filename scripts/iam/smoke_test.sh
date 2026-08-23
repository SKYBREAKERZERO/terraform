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

IAM_ENABLE_SSM="${IAM_ENABLE_SSM:-true}"
IAM_ENABLE_CLOUDWATCH_AGENT="${IAM_ENABLE_CLOUDWATCH_AGENT:-true}"

EXPECTED_ROLE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-role"
EXPECTED_INSTANCE_PROFILE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ec2-instance-profile"

EXPECTED_SSM_POLICY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ssm-core"
EXPECTED_CLOUDWATCH_POLICY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cloudwatch-agent"

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
    echo "[PASS] $1"
}

info() {
    echo "[INFO] $1"
}

fail() {
    echo "[FAIL] $1"
    exit 1
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

get_local_policy_arn() {
    local policy_name="$1"

    aws_iam list-policies \
        --scope Local \
        --query \
            "Policies[?PolicyName=='${policy_name}'].Arn | [0]" \
        --output text \
        2>/dev/null
}


# ============================================================
# Start
# ============================================================

section "IAM SMOKE TEST"

info "Project             : ${PROJECT_NAME}"
info "Environment         : ${ENVIRONMENT}"
info "AWS region          : ${AWS_REGION}"
info "LocalStack endpoint : ${LOCALSTACK_ENDPOINT}"


# ============================================================
# Pre-flight
# ============================================================

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


# ============================================================
# Terraform Outputs
# ============================================================

section "TERRAFORM OUTPUTS"

ROLE_NAME="$(terraform_output_raw "ec2_role_name")"
INSTANCE_PROFILE_NAME="$(terraform_output_raw "ec2_instance_profile_name")"

if [[ -z "${ROLE_NAME}" || "${ROLE_NAME}" == "null" ]]; then
    ROLE_NAME="${EXPECTED_ROLE_NAME}"
fi

if [[ -z "${INSTANCE_PROFILE_NAME}" ||
      "${INSTANCE_PROFILE_NAME}" == "null" ]]; then

    INSTANCE_PROFILE_NAME="${EXPECTED_INSTANCE_PROFILE_NAME}"
fi

[[ "${ROLE_NAME}" == "${EXPECTED_ROLE_NAME}" ]] \
    || fail "Role name=${ROLE_NAME}, expected=${EXPECTED_ROLE_NAME}"

[[ "${INSTANCE_PROFILE_NAME}" == "${EXPECTED_INSTANCE_PROFILE_NAME}" ]] \
    || fail "Instance profile=${INSTANCE_PROFILE_NAME}, expected=${EXPECTED_INSTANCE_PROFILE_NAME}"

pass "Terraform IAM identifiers are correct"


# ============================================================
# IAM Role
# ============================================================

section "EC2 IAM ROLE"

ACTUAL_ROLE_NAME="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.RoleName' \
        --output text
)" || fail "Unable to retrieve IAM role"

[[ "${ACTUAL_ROLE_NAME}" == "${ROLE_NAME}" ]] \
    || fail "IAM role not found: ${ROLE_NAME}"

pass "IAM role exists: ${ROLE_NAME}"


# ============================================================
# Trust Policy
# ============================================================

section "TRUST POLICY"

TRUST_POLICY="$(
    aws_iam get-role \
        --role-name "${ROLE_NAME}" \
        --query 'Role.AssumeRolePolicyDocument' \
        --output json
)" || fail "Unable to read trust policy"

printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq '"sts:AssumeRole"' \
    || fail "Trust policy does not contain sts:AssumeRole"

pass "Trust policy allows sts:AssumeRole"


printf '%s\n' "${TRUST_POLICY}" |
    grep -Fq '"ec2.amazonaws.com"' \
    || fail "Trust policy does not trust ec2.amazonaws.com"

pass "Trust policy trusts EC2 service"


# ============================================================
# Instance Profile
# ============================================================

section "INSTANCE PROFILE"

ACTUAL_PROFILE_NAME="$(
    aws_iam get-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --query 'InstanceProfile.InstanceProfileName' \
        --output text
)" || fail "Unable to retrieve EC2 instance profile"

[[ "${ACTUAL_PROFILE_NAME}" == "${INSTANCE_PROFILE_NAME}" ]] \
    || fail "Unexpected instance profile=${ACTUAL_PROFILE_NAME}"

pass "Instance profile exists: ${INSTANCE_PROFILE_NAME}"


PROFILE_ROLE_NAME="$(
    aws_iam get-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --query 'InstanceProfile.Roles[0].RoleName' \
        --output text
)"

[[ "${PROFILE_ROLE_NAME}" == "${ROLE_NAME}" ]] \
    || fail "Instance profile role=${PROFILE_ROLE_NAME}, expected=${ROLE_NAME}"

pass "Instance profile contains expected EC2 role"


# ============================================================
# Inline Policy Guardrail
# ============================================================

section "INLINE POLICY CHECK"

INLINE_POLICY_COUNT="$(
    aws_iam list-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'length(PolicyNames)' \
        --output text
)"

[[ "${INLINE_POLICY_COUNT}" == "0" ]] \
    || fail "Unexpected inline policies detected: count=${INLINE_POLICY_COUNT}"

pass "No inline IAM policies are configured"


# ============================================================
# SSM Policy
# ============================================================

section "SSM POLICY"

SSM_POLICY_ARN="$(
    get_local_policy_arn "${EXPECTED_SSM_POLICY_NAME}"
)"

if [[ "${IAM_ENABLE_SSM}" == "true" ]]; then

    [[ -n "${SSM_POLICY_ARN}" && "${SSM_POLICY_ARN}" != "None" ]] \
        || fail "SSM policy is missing"

    pass "SSM policy exists"

    SSM_ATTACHMENT_COUNT="$(
        aws_iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query \
                "length(AttachedPolicies[?PolicyArn=='${SSM_POLICY_ARN}'])" \
            --output text
    )"

    [[ "${SSM_ATTACHMENT_COUNT}" == "1" ]] \
        || fail "SSM policy is not attached to EC2 role"

    pass "SSM policy is attached"

else

    [[ -z "${SSM_POLICY_ARN}" || "${SSM_POLICY_ARN}" == "None" ]] \
        || fail "SSM policy exists although SSM is disabled"

    pass "SSM policy is correctly disabled"

fi


# ============================================================
# CloudWatch Agent Policy
# ============================================================

section "CLOUDWATCH AGENT POLICY"

CLOUDWATCH_POLICY_ARN="$(
    get_local_policy_arn "${EXPECTED_CLOUDWATCH_POLICY_NAME}"
)"

if [[ "${IAM_ENABLE_CLOUDWATCH_AGENT}" == "true" ]]; then

    [[ -n "${CLOUDWATCH_POLICY_ARN}" &&
       "${CLOUDWATCH_POLICY_ARN}" != "None" ]] \
        || fail "CloudWatch Agent policy is missing"

    pass "CloudWatch Agent policy exists"

    CLOUDWATCH_ATTACHMENT_COUNT="$(
        aws_iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query \
                "length(AttachedPolicies[?PolicyArn=='${CLOUDWATCH_POLICY_ARN}'])" \
            --output text
    )"

    [[ "${CLOUDWATCH_ATTACHMENT_COUNT}" == "1" ]] \
        || fail "CloudWatch Agent policy is not attached"

    pass "CloudWatch Agent policy is attached"

else

    [[ -z "${CLOUDWATCH_POLICY_ARN}" ||
       "${CLOUDWATCH_POLICY_ARN}" == "None" ]] \
        || fail "CloudWatch Agent policy exists although feature is disabled"

    pass "CloudWatch Agent policy is correctly disabled"

fi


# ============================================================
# Managed Policy Count
# ============================================================

section "POLICY ATTACHMENT COUNT"

EXPECTED_POLICY_COUNT=0

if [[ "${IAM_ENABLE_SSM}" == "true" ]]; then
    EXPECTED_POLICY_COUNT=$((EXPECTED_POLICY_COUNT + 1))
fi

if [[ "${IAM_ENABLE_CLOUDWATCH_AGENT}" == "true" ]]; then
    EXPECTED_POLICY_COUNT=$((EXPECTED_POLICY_COUNT + 1))
fi


ATTACHED_POLICY_COUNT="$(
    aws_iam list-attached-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'length(AttachedPolicies)' \
        --output text
)"

[[ "${ATTACHED_POLICY_COUNT}" == "${EXPECTED_POLICY_COUNT}" ]] \
    || fail "Attached policy count=${ATTACHED_POLICY_COUNT}, expected=${EXPECTED_POLICY_COUNT}"

pass "Managed policy attachment count is correct"


# ============================================================
# High Privilege Guardrail
# ============================================================

section "PRIVILEGE GUARDRAIL"

ATTACHED_POLICY_NAMES="$(
    aws_iam list-attached-role-policies \
        --role-name "${ROLE_NAME}" \
        --query 'AttachedPolicies[].PolicyName' \
        --output text
)"

for forbidden_policy in \
    AdministratorAccess \
    PowerUserAccess \
    IAMFullAccess

do

    if [[ " ${ATTACHED_POLICY_NAMES} " == *" ${forbidden_policy} "* ]]; then
        fail "Forbidden policy attached: ${forbidden_policy}"
    fi

done

pass "No high-privilege managed policy is attached"


# ============================================================
# EC2 Role / Profile Relationship
# ============================================================

section "ROLE / PROFILE ASSOCIATION"

PROFILE_COUNT="$(
    aws_iam list-instance-profiles-for-role \
        --role-name "${ROLE_NAME}" \
        --query \
            "length(InstanceProfiles[?InstanceProfileName=='${INSTANCE_PROFILE_NAME}'])" \
        --output text
)"

[[ "${PROFILE_COUNT}" == "1" ]] \
    || fail "Expected EC2 instance profile association is missing"

pass "Role and instance profile association is healthy"


# ============================================================
# Result
# ============================================================

section "IAM SMOKE TEST RESULT"

echo "[SUCCESS] IAM smoke test passed."