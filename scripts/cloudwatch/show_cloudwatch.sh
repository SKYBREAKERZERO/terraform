#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
)"

PROJECT_ROOT="$(
  cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1
  pwd
)"

SHOW_SCRIPT="${PROJECT_ROOT}/python/src/cloudwatch/show_cloudwatch.py"


# ============================================================
# Environment Defaults
# ============================================================

export LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-test}"

export PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
export ENVIRONMENT="${ENVIRONMENT:-localstack}"

export CLOUDWATCH_ENABLED="${CLOUDWATCH_ENABLED:-true}"

export CLOUDWATCH_ALARM_ENABLED="${CLOUDWATCH_ALARM_ENABLED:-true}"
export CLOUDWATCH_DASHBOARD_ENABLED="${CLOUDWATCH_DASHBOARD_ENABLED:-true}"

export CLOUDWATCH_LOG_RETENTION_IN_DAYS="${CLOUDWATCH_LOG_RETENTION_IN_DAYS:-30}"

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Expected Resource Names
# ============================================================

if [[ -n "${CLOUDWATCH_LOG_GROUP_NAME:-}" ]]; then
  EXPECTED_LOG_GROUP_NAME="${CLOUDWATCH_LOG_GROUP_NAME}"
else
  EXPECTED_LOG_GROUP_NAME="/aws/${PROJECT_NAME}/${ENVIRONMENT}/application"
fi

if [[ -n "${CLOUDWATCH_ALARM_NAME:-}" ]]; then
  EXPECTED_ALARM_NAME="${CLOUDWATCH_ALARM_NAME}"
else
  EXPECTED_ALARM_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alarm"
fi

if [[ -n "${CLOUDWATCH_DASHBOARD_NAME:-}" ]]; then
  EXPECTED_DASHBOARD_NAME="${CLOUDWATCH_DASHBOARD_NAME}"
else
  EXPECTED_DASHBOARD_NAME="${PROJECT_NAME}-${ENVIRONMENT}-dashboard"
fi


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "CLOUDWATCH SHOW"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo "Log Group:           ${EXPECTED_LOG_GROUP_NAME}"
echo "Alarm:               ${EXPECTED_ALARM_NAME}"
echo "Dashboard:           ${EXPECTED_DASHBOARD_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${CLOUDWATCH_ENABLED,,}" != "true" ]]; then
  echo "[INFO] CloudWatch is disabled for this environment."
  echo
  exit 0
fi


# ============================================================
# Python Check
# ============================================================

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 is not installed or not available in PATH."
  exit 1
fi

echo "[PASS] python3 is available."


# ============================================================
# boto3 Check
# ============================================================

if ! python3 -c "import boto3" >/dev/null 2>&1; then
  echo "[ERROR] boto3 is not installed."
  echo
  echo "Install with:"
  echo "  python3 -m pip install boto3"
  exit 1
fi

echo "[PASS] boto3 is available."


# ============================================================
# Show Script Check
# ============================================================

if [[ ! -f "${SHOW_SCRIPT}" ]]; then
  echo "[ERROR] CloudWatch show script was not found:"
  echo "  ${SHOW_SCRIPT}"
  exit 1
fi

echo "[PASS] show_cloudwatch.py exists."


# ============================================================
# LocalStack Health Check
# ============================================================

echo
echo "Checking LocalStack..."

if command -v curl >/dev/null 2>&1; then

  if curl \
    --silent \
    --fail \
    "${LOCALSTACK_ENDPOINT}/_localstack/health" \
    >/dev/null 2>&1; then

    echo "[PASS] LocalStack is reachable."

  else

    echo "[ERROR] LocalStack is not reachable:"
    echo "  ${LOCALSTACK_ENDPOINT}"
    exit 1

  fi

else

  echo "[WARN] curl is not installed."
  echo "[WARN] Skipping LocalStack HTTP health check."

fi


# ============================================================
# CloudWatch API Check
# ============================================================

echo
echo "Checking CloudWatch API..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

client = boto3.client(
    "cloudwatch",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.list_metrics()

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] CloudWatch API check failed: "
        f"{error}"
    )
    sys.exit(1)


status_code = response.get(
    "ResponseMetadata",
    {},
).get(
    "HTTPStatusCode"
)

if status_code != 200:
    print(
        "[ERROR] Unexpected CloudWatch API "
        f"HTTP status: {status_code}"
    )
    sys.exit(1)

print(
    "[PASS] CloudWatch API is available."
)
PY
then
  exit 1
fi


# ============================================================
# CloudWatch Logs API Check
# ============================================================

echo
echo "Checking CloudWatch Logs API..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

client = boto3.client(
    "logs",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.describe_log_groups(
        limit=1,
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] CloudWatch Logs API check failed: "
        f"{error}"
    )
    sys.exit(1)


status_code = response.get(
    "ResponseMetadata",
    {},
).get(
    "HTTPStatusCode"
)

if status_code != 200:
    print(
        "[ERROR] Unexpected CloudWatch Logs API "
        f"HTTP status: {status_code}"
    )
    sys.exit(1)

print(
    "[PASS] CloudWatch Logs API is available."
)
PY
then
  exit 1
fi


# ============================================================
# Expected Log Group Check
# ============================================================

echo
echo "Checking expected Log Group..."

if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "CLOUDWATCH_LOG_GROUP_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"/aws/{project_name}/{environment}/application"
)

client = boto3.client(
    "logs",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.describe_log_groups(
        logGroupNamePrefix=expected_name,
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] Log Group check failed: "
        f"{error}"
    )
    sys.exit(1)


groups = response.get(
    "logGroups",
    [],
)

match = next(
    (
        group
        for group in groups
        if group.get(
            "logGroupName"
        )
        == expected_name
    ),
    None,
)

if match is None:
    print(
        "[ERROR] Expected Log Group does not exist:"
    )
    print(
        f"        {expected_name}"
    )
    sys.exit(1)

print(
    "[PASS] CloudWatch Log Group exists:"
)

print(
    f"       Name: {match.get('logGroupName')}"
)

print(
    f"       ARN:  {match.get('arn')}"
)
PY
then
  exit 1
fi


# ============================================================
# Expected Alarm Check
# ============================================================

if [[ "${CLOUDWATCH_ALARM_ENABLED,,}" == "true" ]]; then

  echo
  echo "Checking expected Metric Alarm..."

  if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "CLOUDWATCH_ALARM_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-alarm"
)

client = boto3.client(
    "cloudwatch",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.describe_alarms(
        AlarmNames=[
            expected_name,
        ],
    )

except (
    ClientError,
    BotoCoreError,
) as error:
    print(
        "[ERROR] Metric Alarm check failed: "
        f"{error}"
    )
    sys.exit(1)


alarms = response.get(
    "MetricAlarms",
    [],
)

if not alarms:
    print(
        "[ERROR] Expected Metric Alarm "
        "does not exist:"
    )
    print(
        f"        {expected_name}"
    )
    sys.exit(1)

alarm = alarms[0]

print(
    "[PASS] CloudWatch Metric Alarm exists:"
)

print(
    f"       Name:  {alarm.get('AlarmName')}"
)

print(
    f"       ARN:   {alarm.get('AlarmArn')}"
)

print(
    f"       State: {alarm.get('StateValue')}"
)
PY
  then
    exit 1
  fi

else

  echo
  echo "[INFO] CloudWatch Metric Alarm is disabled."

fi


# ============================================================
# Expected Dashboard Check
# ============================================================

if [[ "${CLOUDWATCH_DASHBOARD_ENABLED,,}" == "true" ]]; then

  echo
  echo "Checking expected Dashboard..."

  if ! python3 - <<'PY'
import os
import sys

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


endpoint = os.environ["LOCALSTACK_ENDPOINT"]
region = os.environ["AWS_REGION"]

project_name = os.environ["PROJECT_NAME"]
environment = os.environ["ENVIRONMENT"]

configured_name = os.getenv(
    "CLOUDWATCH_DASHBOARD_NAME"
)

expected_name = (
    configured_name
    if configured_name
    else f"{project_name}-{environment}-dashboard"
)

client = boto3.client(
    "cloudwatch",
    region_name=region,
    endpoint_url=endpoint,
)

try:
    response = client.get_dashboard(
        DashboardName=expected_name,
    )

except ClientError as error:
    error_info = error.response.get(
        "Error",
        {},
    )

    error_code = error_info.get(
        "Code",
        "Unknown",
    )

    if error_code in {
        "ResourceNotFound",
        "ResourceNotFoundException",
    }:
        print(
            "[ERROR] Expected Dashboard "
            "does not exist:"
        )
        print(
            f"        {expected_name}"
        )

    else:
        print(
            "[ERROR] Dashboard check failed: "
            f"{error}"
        )

    sys.exit(1)

except BotoCoreError as error:
    print(
        "[ERROR] Dashboard SDK check failed: "
        f"{error}"
    )
    sys.exit(1)


if not response.get(
    "DashboardBody"
):
    print(
        "[ERROR] Dashboard exists but "
        "DashboardBody is empty."
    )
    sys.exit(1)

print(
    "[PASS] CloudWatch Dashboard exists:"
)

print(
    f"       Name: {response.get('DashboardName')}"
)

print(
    f"       ARN:  {response.get('DashboardArn')}"
)
PY
  then
    exit 1
  fi

else

  echo
  echo "[INFO] CloudWatch Dashboard is disabled."

fi


# ============================================================
# Run Show Script
# ============================================================

echo
echo "======================================================================"
echo "CLOUDWATCH DETAILS"
echo "======================================================================"
echo

python3 "${SHOW_SCRIPT}"


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "CLOUDWATCH SHOW RESULT"
echo "======================================================================"
echo
echo "[PASS] CloudWatch information displayed successfully."
echo