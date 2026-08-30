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

VALIDATE_SCRIPT="${PROJECT_ROOT}/python/src/cloudwatch/validate_cloudwatch.py"


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


# ============================================================
# Log Group
# ============================================================

export CLOUDWATCH_LOG_GROUP_NAME="${CLOUDWATCH_LOG_GROUP_NAME:-/aws/${PROJECT_NAME}/${ENVIRONMENT}/application}"

export CLOUDWATCH_LOG_RETENTION_IN_DAYS="${CLOUDWATCH_LOG_RETENTION_IN_DAYS:-30}"

export CLOUDWATCH_LOG_KMS_KEY_ID="${CLOUDWATCH_LOG_KMS_KEY_ID:-}"


# ============================================================
# Metric Alarm
# ============================================================

export CLOUDWATCH_ALARM_ENABLED="${CLOUDWATCH_ALARM_ENABLED:-true}"

export CLOUDWATCH_ALARM_NAME="${CLOUDWATCH_ALARM_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-health-alarm}"

export CLOUDWATCH_ALARM_DESCRIPTION="${CLOUDWATCH_ALARM_DESCRIPTION:-AWS enterprise lab health alarm managed by Terraform}"

export CLOUDWATCH_ALARM_NAMESPACE="${CLOUDWATCH_ALARM_NAMESPACE:-Custom/AWSEnterpriseLab}"

export CLOUDWATCH_ALARM_METRIC_NAME="${CLOUDWATCH_ALARM_METRIC_NAME:-HealthStatus}"

export CLOUDWATCH_ALARM_STATISTIC="${CLOUDWATCH_ALARM_STATISTIC:-Average}"

export CLOUDWATCH_ALARM_PERIOD="${CLOUDWATCH_ALARM_PERIOD:-60}"

export CLOUDWATCH_ALARM_EVALUATION_PERIODS="${CLOUDWATCH_ALARM_EVALUATION_PERIODS:-1}"

export CLOUDWATCH_ALARM_DATAPOINTS_TO_ALARM="${CLOUDWATCH_ALARM_DATAPOINTS_TO_ALARM:-1}"

export CLOUDWATCH_ALARM_THRESHOLD="${CLOUDWATCH_ALARM_THRESHOLD:-1}"

export CLOUDWATCH_ALARM_COMPARISON_OPERATOR="${CLOUDWATCH_ALARM_COMPARISON_OPERATOR:-GreaterThanOrEqualToThreshold}"

export CLOUDWATCH_ALARM_TREAT_MISSING_DATA="${CLOUDWATCH_ALARM_TREAT_MISSING_DATA:-missing}"

export CLOUDWATCH_ALARM_UNIT="${CLOUDWATCH_ALARM_UNIT:-}"

export CLOUDWATCH_ALARM_ACTIONS_ENABLED="${CLOUDWATCH_ALARM_ACTIONS_ENABLED:-true}"


# ============================================================
# Metric Dimensions
# ============================================================

export CLOUDWATCH_METRIC_DIMENSION_NAME="${CLOUDWATCH_METRIC_DIMENSION_NAME:-Environment}"

export CLOUDWATCH_METRIC_DIMENSION_VALUE="${CLOUDWATCH_METRIC_DIMENSION_VALUE:-${ENVIRONMENT}}"


# ============================================================
# Dashboard
# ============================================================

export CLOUDWATCH_DASHBOARD_ENABLED="${CLOUDWATCH_DASHBOARD_ENABLED:-true}"

export CLOUDWATCH_DASHBOARD_NAME="${CLOUDWATCH_DASHBOARD_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-dashboard}"

export CLOUDWATCH_DASHBOARD_PERIOD="${CLOUDWATCH_DASHBOARD_PERIOD:-60}"


# ============================================================
# Python Path
# ============================================================

export PYTHONPATH="${PROJECT_ROOT}/python/src${PYTHONPATH:+:${PYTHONPATH}}"


# ============================================================
# Header
# ============================================================

echo "======================================================================"
echo "CLOUDWATCH VALIDATION"
echo "======================================================================"
echo

echo "Project Root:        ${PROJECT_ROOT}"
echo "Endpoint:            ${LOCALSTACK_ENDPOINT}"
echo "Region:              ${AWS_REGION}"
echo "Project:             ${PROJECT_NAME}"
echo "Environment:         ${ENVIRONMENT}"
echo

echo "Log Group:           ${CLOUDWATCH_LOG_GROUP_NAME}"
echo "Retention:           ${CLOUDWATCH_LOG_RETENTION_IN_DAYS} days"
echo

echo "Alarm Enabled:       ${CLOUDWATCH_ALARM_ENABLED}"
echo "Alarm Name:          ${CLOUDWATCH_ALARM_NAME}"
echo "Namespace:           ${CLOUDWATCH_ALARM_NAMESPACE}"
echo "Metric:              ${CLOUDWATCH_ALARM_METRIC_NAME}"
echo

echo "Dashboard Enabled:   ${CLOUDWATCH_DASHBOARD_ENABLED}"
echo "Dashboard Name:      ${CLOUDWATCH_DASHBOARD_NAME}"
echo


# ============================================================
# Enabled Check
# ============================================================

if [[ "${CLOUDWATCH_ENABLED,,}" != "true" ]]; then
  echo "[PASS] CloudWatch is disabled for this environment."
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
# Validator File Check
# ============================================================

if [[ ! -f "${VALIDATE_SCRIPT}" ]]; then
  echo "[ERROR] CloudWatch validator was not found:"
  echo "  ${VALIDATE_SCRIPT}"
  exit 1
fi

echo "[PASS] validate_cloudwatch.py exists."


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
        "[ERROR] Unexpected CloudWatch Logs "
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
expected_name = os.environ["CLOUDWATCH_LOG_GROUP_NAME"]

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

matched = [
    group
    for group in groups
    if group.get(
        "logGroupName"
    ) == expected_name
]

if not matched:
    print(
        "[ERROR] Expected CloudWatch Log Group "
        "does not exist:"
    )
    print(
        f"        {expected_name}"
    )
    sys.exit(1)


group = matched[0]

print(
    "[PASS] CloudWatch Log Group exists:"
)

print(
    f"       Name:      "
    f"{group.get('logGroupName')}"
)

print(
    f"       Retention: "
    f"{group.get('retentionInDays')}"
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
  echo "Checking expected CloudWatch alarm..."

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
expected_name = os.environ["CLOUDWATCH_ALARM_NAME"]

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
        "[ERROR] CloudWatch alarm check failed: "
        f"{error}"
    )
    sys.exit(1)


alarms = response.get(
    "MetricAlarms",
    [],
)

matched = [
    alarm
    for alarm in alarms
    if alarm.get(
        "AlarmName"
    ) == expected_name
]

if not matched:
    print(
        "[ERROR] Expected CloudWatch alarm "
        "does not exist:"
    )
    print(
        f"        {expected_name}"
    )
    sys.exit(1)


alarm = matched[0]

print(
    "[PASS] CloudWatch alarm exists:"
)

print(
    f"       Name:  "
    f"{alarm.get('AlarmName')}"
)

print(
    f"       State: "
    f"{alarm.get('StateValue')}"
)
PY
  then
    exit 1
  fi

fi


# ============================================================
# Expected Dashboard Check
# ============================================================

if [[ "${CLOUDWATCH_DASHBOARD_ENABLED,,}" == "true" ]]; then

  echo
  echo "Checking expected CloudWatch dashboard..."

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
expected_name = os.environ["CLOUDWATCH_DASHBOARD_NAME"]

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

    print(
        "[ERROR] CloudWatch dashboard "
        "check failed:"
    )

    print(
        f"        "
        f"{error_info.get('Code', 'Unknown')} - "
        f"{error_info.get('Message', str(error))}"
    )

    sys.exit(1)

except BotoCoreError as error:
    print(
        "[ERROR] CloudWatch dashboard SDK "
        f"check failed: {error}"
    )
    sys.exit(1)


body = response.get(
    "DashboardBody"
)

if not body:
    print(
        "[ERROR] CloudWatch dashboard "
        "body is empty."
    )
    sys.exit(1)


print(
    "[PASS] CloudWatch dashboard exists:"
)

print(
    f"       Name: {expected_name}"
)
PY
  then
    exit 1
  fi

fi


# ============================================================
# Validation Configuration
# ============================================================

echo
echo "======================================================================"
echo "VALIDATION CONFIGURATION"
echo "======================================================================"
echo

echo "Log Group:"
echo "  Name:      ${CLOUDWATCH_LOG_GROUP_NAME}"
echo "  Retention: ${CLOUDWATCH_LOG_RETENTION_IN_DAYS}"

if [[ -n "${CLOUDWATCH_LOG_KMS_KEY_ID}" ]]; then
  echo "  KMS Key:   ${CLOUDWATCH_LOG_KMS_KEY_ID}"
else
  echo "  KMS Key:   none"
fi

echo
echo "Alarm:"
echo "  Enabled:              ${CLOUDWATCH_ALARM_ENABLED}"
echo "  Name:                 ${CLOUDWATCH_ALARM_NAME}"
echo "  Description:          ${CLOUDWATCH_ALARM_DESCRIPTION}"
echo "  Namespace:            ${CLOUDWATCH_ALARM_NAMESPACE}"
echo "  Metric:               ${CLOUDWATCH_ALARM_METRIC_NAME}"
echo "  Statistic:            ${CLOUDWATCH_ALARM_STATISTIC}"
echo "  Period:               ${CLOUDWATCH_ALARM_PERIOD}"
echo "  Evaluation Periods:   ${CLOUDWATCH_ALARM_EVALUATION_PERIODS}"
echo "  Datapoints To Alarm:  ${CLOUDWATCH_ALARM_DATAPOINTS_TO_ALARM}"
echo "  Threshold:            ${CLOUDWATCH_ALARM_THRESHOLD}"
echo "  Comparison Operator:  ${CLOUDWATCH_ALARM_COMPARISON_OPERATOR}"
echo "  Treat Missing Data:   ${CLOUDWATCH_ALARM_TREAT_MISSING_DATA}"
echo "  Unit:                 ${CLOUDWATCH_ALARM_UNIT:-none}"
echo "  Actions Enabled:      ${CLOUDWATCH_ALARM_ACTIONS_ENABLED}"

echo
echo "Metric Dimension:"
echo "  ${CLOUDWATCH_METRIC_DIMENSION_NAME}=${CLOUDWATCH_METRIC_DIMENSION_VALUE}"

echo
echo "Dashboard:"
echo "  Enabled: ${CLOUDWATCH_DASHBOARD_ENABLED}"
echo "  Name:    ${CLOUDWATCH_DASHBOARD_NAME}"
echo "  Period:  ${CLOUDWATCH_DASHBOARD_PERIOD}"
echo


# ============================================================
# Run Validator
# ============================================================

echo "======================================================================"
echo "RUNNING CLOUDWATCH VALIDATION"
echo "======================================================================"
echo

set +e

python3 "${VALIDATE_SCRIPT}"

VALIDATE_EXIT_CODE=$?

set -e


# ============================================================
# Result
# ============================================================

echo
echo "======================================================================"
echo "CLOUDWATCH VALIDATION RESULT"
echo "======================================================================"

if [[ ${VALIDATE_EXIT_CODE} -eq 0 ]]; then
  echo
  echo "[PASS] CloudWatch validation completed successfully."
  echo
else
  echo
  echo "[FAIL] CloudWatch validation failed."
  echo "       validator exit code: ${VALIDATE_EXIT_CODE}"
  echo
fi

exit "${VALIDATE_EXIT_CODE}"