#!/usr/bin/env bash

set -u

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-data}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

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

aws_local() {
  aws \
    --endpoint-url="${LOCALSTACK_ENDPOINT}" \
    --region="${AWS_REGION}" \
    "$@"
}

echo "============================================================"
echo "S3 Validation"
echo "============================================================"
echo "Endpoint : ${LOCALSTACK_ENDPOINT}"
echo "Region   : ${AWS_REGION}"
echo "Bucket   : ${S3_BUCKET_NAME}"
echo

# ------------------------------------------------------------
# Connectivity
# ------------------------------------------------------------

if aws_local sts get-caller-identity >/dev/null 2>&1; then
  pass "LocalStack is reachable"
else
  fail "LocalStack is not reachable"
fi

# ------------------------------------------------------------
# Bucket existence
# ------------------------------------------------------------

if aws_local s3api head-bucket \
  --bucket "${S3_BUCKET_NAME}" >/dev/null 2>&1; then
  pass "Bucket exists: ${S3_BUCKET_NAME}"
else
  fail "Bucket does not exist: ${S3_BUCKET_NAME}"
fi

# ------------------------------------------------------------
# Region
# ------------------------------------------------------------

LOCATION="$(
  aws_local s3api get-bucket-location \
    --bucket "${S3_BUCKET_NAME}" \
    --query 'LocationConstraint' \
    --output text 2>/dev/null || true
)"

if [[ "${LOCATION}" == "${AWS_REGION}" ]]; then
  pass "Bucket region is ${AWS_REGION}"
elif [[ "${AWS_REGION}" == "us-east-1" && "${LOCATION}" == "None" ]]; then
  pass "Bucket region is us-east-1"
else
  warn "Bucket region returned '${LOCATION}', expected '${AWS_REGION}'"
fi

# ------------------------------------------------------------
# Versioning
# ------------------------------------------------------------

VERSIONING="$(
  aws_local s3api get-bucket-versioning \
    --bucket "${S3_BUCKET_NAME}" \
    --query 'Status' \
    --output text 2>/dev/null || true
)"

if [[ "${VERSIONING}" == "Enabled" ]]; then
  pass "Versioning enabled"
else
  fail "Versioning is not enabled: ${VERSIONING}"
fi

# ------------------------------------------------------------
# Encryption
# ------------------------------------------------------------

SSE="$(
  aws_local s3api get-bucket-encryption \
    --bucket "${S3_BUCKET_NAME}" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
    --output text 2>/dev/null || true
)"

if [[ "${SSE}" == "AES256" || "${SSE}" == "aws:kms" ]]; then
  pass "Server-side encryption enabled: ${SSE}"
else
  fail "Invalid or missing server-side encryption: ${SSE}"
fi

# ------------------------------------------------------------
# Public Access Block
# ------------------------------------------------------------

PUBLIC_ACCESS="$(
  aws_local s3api get-public-access-block \
    --bucket "${S3_BUCKET_NAME}" \
    --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
    --output text 2>/dev/null || true
)"

read -r BLOCK_ACLS IGNORE_ACLS BLOCK_POLICY RESTRICT_PUBLIC <<< "${PUBLIC_ACCESS}"

[[ "${BLOCK_ACLS}" == "True" ]] \
  && pass "BlockPublicAcls enabled" \
  || fail "BlockPublicAcls disabled"

[[ "${IGNORE_ACLS}" == "True" ]] \
  && pass "IgnorePublicAcls enabled" \
  || fail "IgnorePublicAcls disabled"

[[ "${BLOCK_POLICY}" == "True" ]] \
  && pass "BlockPublicPolicy enabled" \
  || fail "BlockPublicPolicy disabled"

[[ "${RESTRICT_PUBLIC}" == "True" ]] \
  && pass "RestrictPublicBuckets enabled" \
  || fail "RestrictPublicBuckets disabled"

# ------------------------------------------------------------
# Tags
# ------------------------------------------------------------

PROJECT_TAG="$(
  aws_local s3api get-bucket-tagging \
    --bucket "${S3_BUCKET_NAME}" \
    --query "TagSet[?Key=='Project'].Value | [0]" \
    --output text 2>/dev/null || true
)"

ENV_TAG="$(
  aws_local s3api get-bucket-tagging \
    --bucket "${S3_BUCKET_NAME}" \
    --query "TagSet[?Key=='Environment'].Value | [0]" \
    --output text 2>/dev/null || true
)"

SERVICE_TAG="$(
  aws_local s3api get-bucket-tagging \
    --bucket "${S3_BUCKET_NAME}" \
    --query "TagSet[?Key=='Service'].Value | [0]" \
    --output text 2>/dev/null || true
)"

[[ "${PROJECT_TAG}" == "${PROJECT_NAME}" ]] \
  && pass "Project tag correct" \
  || fail "Project tag mismatch: ${PROJECT_TAG}"

[[ "${ENV_TAG}" == "${ENVIRONMENT}" ]] \
  && pass "Environment tag correct" \
  || fail "Environment tag mismatch: ${ENV_TAG}"

[[ "${SERVICE_TAG}" == "s3" ]] \
  && pass "Service tag correct" \
  || fail "Service tag mismatch: ${SERVICE_TAG}"

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo "S3 Validation Summary"
echo "============================================================"
echo "PASS : ${PASS_COUNT}"
echo "WARN : ${WARN_COUNT}"
echo "FAIL : ${FAIL_COUNT}"
echo "============================================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0