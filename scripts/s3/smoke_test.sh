#!/usr/bin/env bash

set -u

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-data}"

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

aws_local() {
  aws \
    --endpoint-url="${LOCALSTACK_ENDPOINT}" \
    --region="${AWS_REGION}" \
    "$@"
}

TEST_KEY="smoke/s3-smoke-$(date +%s).txt"
UPLOAD_FILE="$(mktemp)"
DOWNLOAD_FILE="$(mktemp)"

cleanup() {
  rm -f "${UPLOAD_FILE}" "${DOWNLOAD_FILE}"
}

trap cleanup EXIT

echo "localstack-s3-smoke-test" > "${UPLOAD_FILE}"

echo "============================================================"
echo "S3 Smoke Test"
echo "============================================================"
echo "Bucket : ${S3_BUCKET_NAME}"
echo "Key    : ${TEST_KEY}"
echo

if aws_local s3api head-bucket \
  --bucket "${S3_BUCKET_NAME}" >/dev/null 2>&1; then
  pass "Bucket reachable"
else
  fail "Bucket not reachable"
fi

PUT_OUTPUT="$(
  aws_local s3api put-object \
    --bucket "${S3_BUCKET_NAME}" \
    --key "${TEST_KEY}" \
    --body "${UPLOAD_FILE}" \
    --output json 2>/dev/null
)"

if [[ $? -eq 0 ]]; then
  pass "PutObject succeeded"
else
  fail "PutObject failed"
fi

if aws_local s3api head-object \
  --bucket "${S3_BUCKET_NAME}" \
  --key "${TEST_KEY}" >/dev/null 2>&1; then
  pass "HeadObject succeeded"
else
  fail "HeadObject failed"
fi

if aws_local s3api get-object \
  --bucket "${S3_BUCKET_NAME}" \
  --key "${TEST_KEY}" \
  "${DOWNLOAD_FILE}" >/dev/null 2>&1; then

  pass "GetObject succeeded"

  if cmp -s "${UPLOAD_FILE}" "${DOWNLOAD_FILE}"; then
    pass "Downloaded content matches uploaded content"
  else
    fail "Downloaded content mismatch"
  fi
else
  fail "GetObject failed"
fi

VERSION_ID="$(
  aws_local s3api list-object-versions \
    --bucket "${S3_BUCKET_NAME}" \
    --prefix "${TEST_KEY}" \
    --query 'Versions[0].VersionId' \
    --output text 2>/dev/null || true
)"

if [[ -n "${VERSION_ID}" && "${VERSION_ID}" != "None" ]]; then
  pass "VersionId created: ${VERSION_ID}"
else
  fail "Object version was not created"
fi

if aws_local s3api delete-object \
  --bucket "${S3_BUCKET_NAME}" \
  --key "${TEST_KEY}" >/dev/null 2>&1; then
  pass "DeleteObject succeeded"
else
  fail "DeleteObject failed"
fi

echo
echo "============================================================"
echo "S3 Smoke Test Summary"
echo "============================================================"
echo "PASS : ${PASS_COUNT}"
echo "FAIL : ${FAIL_COUNT}"
echo "============================================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi

exit 0