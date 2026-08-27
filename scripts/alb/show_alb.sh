#!/usr/bin/env bash

set -euo pipefail

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"


aws_ls() {
  aws \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    "$@"
}


print_line() {
  printf '%*s\n' 70 '' | tr ' ' '='
}


print_line
echo "ALB"
print_line

ALB_JSON="$(
  aws_ls elbv2 describe-load-balancers \
    --names "${ALB_NAME}"
)"

ALB_ARN="$(
  echo "${ALB_JSON}" \
    | jq -r '.LoadBalancers[0].LoadBalancerArn'
)"

if [[ -z "${ALB_ARN}" || "${ALB_ARN}" == "null" ]]; then
  echo "ALB not found: ${ALB_NAME}"
  exit 1
fi

echo "${ALB_JSON}" | jq -r '
  .LoadBalancers[0] |
  "Name:             \(.LoadBalancerName)",
  "ARN:              \(.LoadBalancerArn)",
  "DNS:              \(.DNSName)",
  "Scheme:           \(.Scheme)",
  "Type:             \(.Type)",
  "State:            \(.State.Code)",
  "VPC:              \(.VpcId)"
'

echo
echo "Availability Zones"

echo "${ALB_JSON}" | jq -r '
  .LoadBalancers[0].AvailabilityZones[]? |
  "  \(.ZoneName): \(.SubnetId)"
'

echo
echo "Security Groups"

echo "${ALB_JSON}" | jq -r '
  .LoadBalancers[0].SecurityGroups[]? |
  "  \(.)"
'

echo

print_line
echo "TARGET GROUPS"
print_line

TG_JSON="$(
  aws_ls elbv2 describe-target-groups \
    --load-balancer-arn "${ALB_ARN}"
)"

TG_COUNT="$(
  echo "${TG_JSON}" \
    | jq '.TargetGroups | length'
)"

if [[ "${TG_COUNT}" -eq 0 ]]; then
  echo "No target groups found."
else
  echo "${TG_JSON}" \
    | jq -c '.TargetGroups[]' \
    | while read -r TARGET_GROUP; do

        TG_ARN="$(
          echo "${TARGET_GROUP}" \
            | jq -r '.TargetGroupArn'
        )"

        echo "${TARGET_GROUP}" | jq -r '
          "Name:             \(.TargetGroupName)",
          "ARN:              \(.TargetGroupArn)",
          "Protocol:         \(.Protocol)",
          "Port:             \(.Port)",
          "Target Type:      \(.TargetType)",
          "VPC:              \(.VpcId)",
          "Health Check:     \(.HealthCheckProtocol) \(.HealthCheckPath)",
          "Interval:         \(.HealthCheckIntervalSeconds)",
          "Timeout:          \(.HealthCheckTimeoutSeconds)",
          "Healthy Count:    \(.HealthyThresholdCount)",
          "Unhealthy Count:  \(.UnhealthyThresholdCount)"
        '

        echo
        echo "Targets:"

        TARGET_HEALTH_JSON="$(
          aws_ls elbv2 describe-target-health \
            --target-group-arn "${TG_ARN}"
        )"

        TARGET_COUNT="$(
          echo "${TARGET_HEALTH_JSON}" \
            | jq '.TargetHealthDescriptions | length'
        )"

        if [[ "${TARGET_COUNT}" -eq 0 ]]; then
          echo "  No registered targets."
        else
          echo "${TARGET_HEALTH_JSON}" | jq -r '
            .TargetHealthDescriptions[] |
            "  \(.Target.Id) port=\(.Target.Port) state=\(.TargetHealth.State)"
          '
        fi

        echo
      done
fi


print_line
echo "LISTENERS"
print_line

LISTENER_JSON="$(
  aws_ls elbv2 describe-listeners \
    --load-balancer-arn "${ALB_ARN}"
)"

LISTENER_COUNT="$(
  echo "${LISTENER_JSON}" \
    | jq '.Listeners | length'
)"

if [[ "${LISTENER_COUNT}" -eq 0 ]]; then
  echo "No listeners found."
else
  echo "${LISTENER_JSON}" | jq -r '
    .Listeners[] |
    "\(.Protocol):\(.Port)",
    (
      .DefaultActions[]? |
      "  action=\(.Type)",
      (
        if .TargetGroupArn then
          "  target_group=\(.TargetGroupArn)"
        else
          empty
        end
      )
    )
  '
fi


echo
print_line
echo "TAGS"
print_line

TAG_JSON="$(
  aws_ls elbv2 describe-tags \
    --resource-arns "${ALB_ARN}"
)"

echo "${TAG_JSON}" | jq -r '
  .TagDescriptions[0].Tags
  | sort_by(.Key)
  | .[]?
  | "\(.Key)=\(.Value)"
'