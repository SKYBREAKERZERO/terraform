#!/usr/bin/env bash

set -euo pipefail

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-data}"

aws_local() {
  aws \
    --endpoint-url="${LOCALSTACK_ENDPOINT}" \
    --region="${AWS_REGION}" \
    "$@"
}

echo "============================================================"
echo "S3 Resource Summary"
echo "============================================================"

echo
echo "[Buckets]"
aws_local s3api list-buckets \
  --query 'Buckets[*].[Name,CreationDate]' \
  --output table

echo
echo "[Target Bucket]"
echo "Bucket: ${S3_BUCKET_NAME}"

echo
echo "[Location]"
aws_local s3api get-bucket-location \
  --bucket "${S3_BUCKET_NAME}" \
  --output json

echo
echo "[Versioning]"
aws_local s3api get-bucket-versioning \
  --bucket "${S3_BUCKET_NAME}" \
  --output json

echo
echo "[Encryption]"
aws_local s3api get-bucket-encryption \
  --bucket "${S3_BUCKET_NAME}" \
  --output json

echo
echo "[Public Access Block]"
aws_local s3api get-public-access-block \
  --bucket "${S3_BUCKET_NAME}" \
  --output json

echo
echo "[Tags]"
aws_local s3api get-bucket-tagging \
  --bucket "${S3_BUCKET_NAME}" \
  --output table

echo
echo "[Lifecycle]"
if aws_local s3api get-bucket-lifecycle-configuration \
  --bucket "${S3_BUCKET_NAME}" \
  --output json 2>/dev/null; then
  :
else
  echo "Lifecycle configuration not configured."
fi

echo
echo "[Objects]"
aws_local s3api list-objects-v2 \
  --bucket "${S3_BUCKET_NAME}" \
  --query 'Contents[*].[Key,Size,LastModified]' \
  --output table