#!/usr/bin/env bash

set -euo pipefail

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
TARGET_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-app-tg"

PASS=0
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

fail() {
  FAIL=$((FAIL + 1))
  echo "[FAIL] $1"
}

separator() {
  printf '%*s\n' 70 '' | tr ' ' '='
}

separator
echo "ALB SMOKE TEST"
separator

# ------------------------------------------------------------
# 1. ALB exists
# ------------------------------------------------------------

if ! ALB_JSON="$(
  aws_ls elbv2 describe-load-balancers \
    --names "${ALB_NAME}" \
    2>/dev/null
)"; then
  fail "ALB exists: ${ALB_NAME}"

  echo
  separator
  echo "SUMMARY"
  separator
  echo "PASS: ${PASS}"
  echo "FAIL: ${FAIL}"

  exit 1
fi

ALB_ARN="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].LoadBalancerArn // empty'
)"

if [[ -n "${ALB_ARN}" ]]; then
  pass "ALB exists: ${ALB_NAME}"
else
  fail "ALB ARN is missing"

  exit 1
fi

# ------------------------------------------------------------
# 2. ALB type
# ------------------------------------------------------------

ALB_TYPE="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].Type // empty'
)"

if [[ "${ALB_TYPE}" == "application" ]]; then
  pass "ALB type is application"
else
  fail "ALB type expected application, got ${ALB_TYPE}"
fi

# ------------------------------------------------------------
# 3. ALB scheme
# ------------------------------------------------------------

ALB_SCHEME="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].Scheme // empty'
)"

if [[ "${ALB_SCHEME}" == "internet-facing" ]]; then
  pass "ALB scheme is internet-facing"
else
  fail "ALB scheme expected internet-facing, got ${ALB_SCHEME}"
fi

# ------------------------------------------------------------
# 4. ALB state
# ------------------------------------------------------------

ALB_STATE="$(
  echo "${ALB_JSON}" |
    jq -r '.LoadBalancers[0].State.Code // empty'
)"

if [[ "${ALB_STATE}" == "active" ]]; then
  pass "ALB state is active"
else
  fail "ALB state expected active, got ${ALB_STATE}"
fi

# ------------------------------------------------------------
# 5. ALB spans at least two subnets
# ------------------------------------------------------------

SUBNET_COUNT="$(
  echo "${ALB_JSON}" |
    jq '.LoadBalancers[0].AvailabilityZones | length'
)"

if [[ "${SUBNET_COUNT}" -ge 2 ]]; then
  pass "ALB spans at least two subnets"
else
  fail "ALB expected at least 2 subnets, found ${SUBNET_COUNT}"
fi

# ------------------------------------------------------------
# 6. Security group attached
# ------------------------------------------------------------

SG_COUNT="$(
  echo "${ALB_JSON}" |
    jq '.LoadBalancers[0].SecurityGroups | length'
)"

if [[ "${SG_COUNT}" -ge 1 ]]; then
  pass "ALB has security group"
else
  fail "ALB has no security group"
fi

# ------------------------------------------------------------
# 7. Target group exists
# ------------------------------------------------------------

if ! TG_JSON="$(
  aws_ls elbv2 describe-target-groups \
    --names "${TARGET_GROUP_NAME}" \
    2>/dev/null
)"; then
  fail "Target group exists: ${TARGET_GROUP_NAME}"
  TG_JSON='{"TargetGroups":[]}'
else
  TG_COUNT="$(
    echo "${TG_JSON}" |
      jq '.TargetGroups | length'
  )"

  if [[ "${TG_COUNT}" -eq 1 ]]; then
    pass "Target group exists: ${TARGET_GROUP_NAME}"
  else
    fail "Expected exactly one target group, found ${TG_COUNT}"
  fi
fi

TG_ARN="$(
  echo "${TG_JSON}" |
    jq -r '.TargetGroups[0].TargetGroupArn // empty'
)"

if [[ -n "${TG_ARN}" ]]; then

  # ----------------------------------------------------------
  # 8. Target group protocol
  # ----------------------------------------------------------

  TG_PROTOCOL="$(
    echo "${TG_JSON}" |
      jq -r '.TargetGroups[0].Protocol // empty'
  )"

  if [[ "${TG_PROTOCOL}" == "HTTP" ]]; then
    pass "Target group protocol is HTTP"
  else
    fail "Target group protocol expected HTTP, got ${TG_PROTOCOL}"
  fi

  # ----------------------------------------------------------
  # 9. Target group port
  # ----------------------------------------------------------

  TG_PORT="$(
    echo "${TG_JSON}" |
      jq -r '.TargetGroups[0].Port // empty'
  )"

  if [[ "${TG_PORT}" == "80" ]]; then
    pass "Target group port is 80"
  else
    fail "Target group port expected 80, got ${TG_PORT}"
  fi

  # ----------------------------------------------------------
  # 10. Target type
  # ----------------------------------------------------------

  TARGET_TYPE="$(
    echo "${TG_JSON}" |
      jq -r '.TargetGroups[0].TargetType // empty'
  )"

  if [[ "${TARGET_TYPE}" == "instance" ]]; then
    pass "Target type is instance"
  else
    fail "Target type expected instance, got ${TARGET_TYPE}"
  fi

  # ----------------------------------------------------------
  # 11. Health check path
  # ----------------------------------------------------------

  HEALTH_PATH="$(
    echo "${TG_JSON}" |
      jq -r '.TargetGroups[0].HealthCheckPath // empty'
  )"

  if [[ "${HEALTH_PATH}" == "/" ]]; then
    pass "Health check path is /"
  else
    fail "Health check path expected /, got ${HEALTH_PATH}"
  fi

  # ----------------------------------------------------------
  # 12. Registered targets
  # ----------------------------------------------------------

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
    fail "Expected at least 2 registered targets, found ${TARGET_COUNT}"
  fi

else
  fail "Target group ARN is missing"
fi

# ------------------------------------------------------------
# 13. Listener exists
# ------------------------------------------------------------

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

  # ----------------------------------------------------------
  # 14. Listener protocol
  # ----------------------------------------------------------

  LISTENER_PROTOCOL="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].Protocol // empty'
  )"

  if [[ "${LISTENER_PROTOCOL}" == "HTTP" ]]; then
    pass "Listener protocol is HTTP"
  else
    fail "Listener protocol expected HTTP, got ${LISTENER_PROTOCOL}"
  fi

  # ----------------------------------------------------------
  # 15. Listener port
  # ----------------------------------------------------------

  LISTENER_PORT="$(
    echo "${LISTENER_JSON}" |
      jq -r '.Listeners[0].Port // empty'
  )"

  if [[ "${LISTENER_PORT}" == "80" ]]; then
    pass "Listener port is 80"
  else
    fail "Listener port expected 80, got ${LISTENER_PORT}"
  fi

  # ----------------------------------------------------------
  # 16. Listener forward action
  # ----------------------------------------------------------

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

  if [[ -n "${TG_ARN}" && "${FORWARD_TG_ARN}" == "${TG_ARN}" ]]; then
    pass "Listener forwards to expected target group"
  else
    fail "Listener does not forward to expected target group"
  fi
fi

echo
separator
echo "SUMMARY"
separator
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi

exit 0