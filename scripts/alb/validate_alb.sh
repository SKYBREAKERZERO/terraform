#!/usr/bin/env bash

set -euo pipefail

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
TARGET_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app-tg"

EXPECTED_LISTENER_PORT="80"
EXPECTED_LISTENER_PROTOCOL="HTTP"

EXPECTED_TARGET_PORT="80"
EXPECTED_TARGET_PROTOCOL="HTTP"
EXPECTED_TARGET_TYPE="instance"

EXPECTED_HEALTH_CHECK_PROTOCOL="HTTP"
EXPECTED_HEALTH_CHECK_PATH="/"
EXPECTED_HEALTH_CHECK_INTERVAL="30"
EXPECTED_HEALTH_CHECK_TIMEOUT="5"
EXPECTED_HEALTHY_THRESHOLD="2"
EXPECTED_UNHEALTHY_THRESHOLD="3"

PASS=0
WARN=0
FAIL=0

aws_ls() {
  aws \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    "$@"
}

pass() {
  PASS=$((PASS + 1))
  echo "[PASS] $1"
}

warn() {
  WARN=$((WARN + 1))
  echo "[WARN] $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "[FAIL] $1"
}

separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}

summary() {
  echo
  separator
  echo "ALB VALIDATION SUMMARY"
  separator
  echo "PASS: ${PASS}"
  echo "WARN: ${WARN}"
  echo "FAIL: ${FAIL}"
}

separator
echo "ALB VALIDATION"
separator

# ============================================================
# ALB
# ============================================================

if ! ALB_JSON="$(
  aws_ls elbv2 describe-load-balancers \
    --names "${ALB_NAME}" \
    2>/dev/null
)"; then
  fail "ALB not found: ${ALB_NAME}"
  summary
  exit 1
fi

ALB_ARN="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].LoadBalancerArn // empty'
)"

if [[ -z "${ALB_ARN}" ]]; then
  fail "ALB ARN is missing"
  summary
  exit 1
fi

pass "ALB exists: ${ALB_NAME}"

ALB_TYPE="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].Type // empty'
)"

if [[ "${ALB_TYPE}" == "application" ]]; then
  pass "ALB type is application"
else
  fail "ALB type expected application, got ${ALB_TYPE}"
fi

ALB_SCHEME="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].Scheme // empty'
)"

if [[ "${ALB_SCHEME}" == "internet-facing" ]]; then
  pass "ALB scheme is internet-facing"
else
  fail "ALB scheme expected internet-facing, got ${ALB_SCHEME}"
fi

ALB_STATE="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].State.Code // empty'
)"

if [[ "${ALB_STATE}" == "active" ]]; then
  pass "ALB state is active"
elif [[ -n "${ALB_STATE}" ]]; then
  warn "ALB state is ${ALB_STATE}"
else
  fail "ALB state is missing"
fi

ALB_VPC_ID="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].VpcId // empty'
)"

if [[ -n "${ALB_VPC_ID}" ]]; then
  pass "ALB VPC ID exists: ${ALB_VPC_ID}"
else
  fail "ALB VPC ID is missing"
fi

ALB_DNS="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].DNSName // empty'
)"

if [[ -n "${ALB_DNS}" ]]; then
  pass "ALB DNS name exists: ${ALB_DNS}"
else
  fail "ALB DNS name is missing"
fi

# ============================================================
# ALB Subnets / AZ
# ============================================================

SUBNET_COUNT="$(
  echo "${ALB_JSON}" |
    jq '.LoadBalancers[0].AvailabilityZones | length'
)"

if [[ "${SUBNET_COUNT}" -ge 2 ]]; then
  pass "ALB spans at least two subnets"
else
  fail "Expected at least two ALB subnets, found ${SUBNET_COUNT}"
fi

AZ_COUNT="$(
  echo "${ALB_JSON}" |
    jq '
      [
        .LoadBalancers[0].AvailabilityZones[].ZoneName
      ]
      | unique
      | length
    '
)"

if [[ "${AZ_COUNT}" -ge 2 ]]; then
  pass "ALB spans at least two availability zones"
else
  fail "Expected at least two availability zones, found ${AZ_COUNT}"
fi

# ============================================================
# ALB Security Groups
# ============================================================

SG_COUNT="$(
  echo "${ALB_JSON}" |
    jq '.LoadBalancers[0].SecurityGroups | length'
)"

if [[ "${SG_COUNT}" -ge 1 ]]; then
  pass "ALB has at least one security group"
else
  fail "ALB has no security group"
fi

# ============================================================
# Target Group
# ============================================================

if ! TG_JSON="$(
  aws_ls elbv2 describe-target-groups \
    --names "${TARGET_GROUP_NAME}" \
    2>/dev/null
)"; then
  fail "Target group not found: ${TARGET_GROUP_NAME}"
  summary
  exit 1
fi

TG_COUNT="$(
  echo "${TG_JSON}" |
    jq '.TargetGroups | length'
)"

if [[ "${TG_COUNT}" -eq 1 ]]; then
  pass "Exactly one target group exists"
else
  fail "Expected exactly one target group, found ${TG_COUNT}"
fi

TG_ARN="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].TargetGroupArn // empty'
)"

if [[ -z "${TG_ARN}" ]]; then
  fail "Target group ARN is missing"
  summary
  exit 1
fi

TG_NAME="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].TargetGroupName // empty'
)"

if [[ "${TG_NAME}" == "${TARGET_GROUP_NAME}" ]]; then
  pass "Target group name is correct"
else
  fail "Unexpected target group name: ${TG_NAME}"
fi

TG_PROTOCOL="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].Protocol // empty'
)"

if [[ "${TG_PROTOCOL}" == "${EXPECTED_TARGET_PROTOCOL}" ]]; then
  pass "Target group protocol is HTTP"
else
  fail "Target group protocol expected HTTP, got ${TG_PROTOCOL}"
fi

TG_PORT="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].Port // empty'
)"

if [[ "${TG_PORT}" == "${EXPECTED_TARGET_PORT}" ]]; then
  pass "Target group port is 80"
else
  fail "Target group port expected 80, got ${TG_PORT}"
fi

TG_TARGET_TYPE="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].TargetType // empty'
)"

if [[ "${TG_TARGET_TYPE}" == "${EXPECTED_TARGET_TYPE}" ]]; then
  pass "Target type is instance"
else
  fail "Target type expected instance, got ${TG_TARGET_TYPE}"
fi

TG_VPC_ID="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].VpcId // empty'
)"

if [[ "${TG_VPC_ID}" == "${ALB_VPC_ID}" ]]; then
  pass "Target group and ALB use the same VPC"
else
  fail "Target group VPC differs from ALB VPC"
fi

# ============================================================
# Health Check
# ============================================================

HEALTH_ENABLED="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthCheckEnabled // false'
)"

if [[ "${HEALTH_ENABLED}" == "true" ]]; then
  pass "Health check is enabled"
else
  fail "Health check is disabled"
fi

HEALTH_PROTOCOL="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthCheckProtocol // empty'
)"

if [[ "${HEALTH_PROTOCOL}" == "${EXPECTED_HEALTH_CHECK_PROTOCOL}" ]]; then
  pass "Health check protocol is HTTP"
else
  fail "Health check protocol expected HTTP, got ${HEALTH_PROTOCOL}"
fi

HEALTH_PATH="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthCheckPath // empty'
)"

if [[ "${HEALTH_PATH}" == "${EXPECTED_HEALTH_CHECK_PATH}" ]]; then
  pass "Health check path is /"
else
  fail "Health check path expected /, got ${HEALTH_PATH}"
fi

HEALTH_INTERVAL="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthCheckIntervalSeconds // empty'
)"

if [[ "${HEALTH_INTERVAL}" == "${EXPECTED_HEALTH_CHECK_INTERVAL}" ]]; then
  pass "Health check interval is 30 seconds"
else
  fail "Health check interval expected 30, got ${HEALTH_INTERVAL}"
fi

HEALTH_TIMEOUT="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthCheckTimeoutSeconds // empty'
)"

if [[ "${HEALTH_TIMEOUT}" == "${EXPECTED_HEALTH_CHECK_TIMEOUT}" ]]; then
  pass "Health check timeout is 5 seconds"
else
  fail "Health check timeout expected 5, got ${HEALTH_TIMEOUT}"
fi

HEALTHY_THRESHOLD="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].HealthyThresholdCount // empty'
)"

if [[ "${HEALTHY_THRESHOLD}" == "${EXPECTED_HEALTHY_THRESHOLD}" ]]; then
  pass "Healthy threshold is 2"
else
  fail "Healthy threshold expected 2, got ${HEALTHY_THRESHOLD}"
fi

UNHEALTHY_THRESHOLD="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].UnhealthyThresholdCount // empty'
)"

if [[ "${UNHEALTHY_THRESHOLD}" == "${EXPECTED_UNHEALTHY_THRESHOLD}" ]]; then
  pass "Unhealthy threshold is 3"
else
  fail "Unhealthy threshold expected 3, got ${UNHEALTHY_THRESHOLD}"
fi

# ============================================================
# Targets
# ============================================================

TARGET_HEALTH_JSON="$(
  aws_ls elbv2 describe-target-health \
    --target-group-arn "${TG_ARN}"
)"

TARGET_COUNT="$(
  echo "${TARGET_HEALTH_JSON}" |
    jq '.TargetHealthDescriptions | length'
)"

if [[ "${TARGET_COUNT}" -ge 2 ]]; then
  pass "At least two targets are registered"
else
  fail "Expected at least two targets, found ${TARGET_COUNT}"
fi

while IFS=$'\t' read -r TARGET_ID TARGET_PORT TARGET_STATE; do
  [[ -z "${TARGET_ID}" ]] && continue

  if [[ -n "${TARGET_ID}" ]]; then
    pass "Target ID exists: ${TARGET_ID}"
  else
    fail "Target ID is missing"
  fi

  if [[ "${TARGET_PORT}" == "${EXPECTED_TARGET_PORT}" ]]; then
    pass "Target ${TARGET_ID} uses port 80"
  else
    fail "Target ${TARGET_ID} uses unexpected port ${TARGET_PORT}"
  fi

  case "${TARGET_STATE}" in
    healthy)
      pass "Target ${TARGET_ID} is healthy"
      ;;
    initial|unused|unavailable|draining)
      warn "Target ${TARGET_ID} health state is ${TARGET_STATE}"
      ;;
    unhealthy)
      warn "Target ${TARGET_ID} is unhealthy"
      ;;
    *)
      warn "Target ${TARGET_ID} returned unknown health state: ${TARGET_STATE}"
      ;;
  esac
done < <(
  echo "${TARGET_HEALTH_JSON}" |
    jq -r '
      .TargetHealthDescriptions[]? |
      [
        .Target.Id,
        (.Target.Port | tostring),
        .TargetHealth.State
      ] |
      @tsv
    '
)

# ============================================================
# Listener
# ============================================================

LISTENER_JSON="$(
  aws_ls elbv2 describe-listeners \
    --load-balancer-arn "${ALB_ARN}"
)"

LISTENER_COUNT="$(
  echo "${LISTENER_JSON}" |
    jq '.Listeners | length'
)"

if [[ "${LISTENER_COUNT}" -eq 1 ]]; then
  pass "Exactly one listener exists"
else
  fail "Expected exactly one listener, found ${LISTENER_COUNT}"
fi

if [[ "${LISTENER_COUNT}" -ge 1 ]]; then
  LISTENER_PROTOCOL="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].Protocol // empty'
  )"

  if [[ "${LISTENER_PROTOCOL}" == "${EXPECTED_LISTENER_PROTOCOL}" ]]; then
    pass "Listener protocol is HTTP"
  else
    fail "Listener protocol expected HTTP, got ${LISTENER_PROTOCOL}"
  fi

  LISTENER_PORT="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].Port // empty'
  )"

  if [[ "${LISTENER_PORT}" == "${EXPECTED_LISTENER_PORT}" ]]; then
    pass "Listener port is 80"
  else
    fail "Listener port expected 80, got ${LISTENER_PORT}"
  fi

  ACTION_TYPE="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].DefaultActions[0].Type // empty'
  )"

  if [[ "${ACTION_TYPE}" == "forward" ]]; then
    pass "Listener default action is forward"
  else
    fail "Listener default action expected forward, got ${ACTION_TYPE}"
  fi

  FORWARD_TG_ARN="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].DefaultActions[0].TargetGroupArn // empty'
  )"

  if [[ "${FORWARD_TG_ARN}" == "${TG_ARN}" ]]; then
    pass "Listener forwards to expected target group"
  else
    fail "Listener forwards to unexpected target group"
  fi
fi

# ============================================================
# Tags
# ============================================================

TAG_JSON="$(
  aws_ls elbv2 describe-tags \
    --resource-arns "${ALB_ARN}"
)"

PROJECT_TAG="$(
  echo "${TAG_JSON}" |
    jq -r '
      .TagDescriptions[0].Tags[]?
      | select(.Key == "Project")
      | .Value
    ' |
    head -n 1
)"

ENVIRONMENT_TAG="$(
  echo "${TAG_JSON}" |
    jq -r '
      .TagDescriptions[0].Tags[]?
      | select(.Key == "Environment")
      | .Value
    ' |
    head -n 1
)"

COMPONENT_TAG="$(
  echo "${TAG_JSON}" |
    jq -r '
      .TagDescriptions[0].Tags[]?
      | select(.Key == "Component")
      | .Value
    ' |
    head -n 1
)"

SERVICE_TAG="$(
  echo "${TAG_JSON}" |
    jq -r '
      .TagDescriptions[0].Tags[]?
      | select(.Key == "Service")
      | .Value
    ' |
    head -n 1
)"

TIER_TAG="$(
  echo "${TAG_JSON}" |
    jq -r '
      .TagDescriptions[0].Tags[]?
      | select(.Key == "Tier")
      | .Value
    ' |
    head -n 1
)"

if [[ "${PROJECT_TAG}" == "${PROJECT_NAME}" ]]; then
  pass "Project tag is ${PROJECT_NAME}"
else
  fail "Project tag expected ${PROJECT_NAME}, got ${PROJECT_TAG}"
fi

if [[ "${ENVIRONMENT_TAG}" == "${ENVIRONMENT}" ]]; then
  pass "Environment tag is ${ENVIRONMENT}"
else
  fail "Environment tag expected ${ENVIRONMENT}, got ${ENVIRONMENT_TAG}"
fi

if [[ "${COMPONENT_TAG}" == "load-balancer" ]]; then
  pass "Component tag is load-balancer"
else
  fail "Component tag expected load-balancer, got ${COMPONENT_TAG}"
fi

if [[ "${SERVICE_TAG}" == "alb" ]]; then
  pass "Service tag is alb"
else
  fail "Service tag expected alb, got ${SERVICE_TAG}"
fi

if [[ "${TIER_TAG}" == "public" ]]; then
  pass "Tier tag is public"
else
  fail "Tier tag expected public, got ${TIER_TAG}"
fi

# ============================================================
# Summary
# ============================================================

summary

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi

exit 0