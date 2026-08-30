import json
import os
import sys
from typing import Any

import boto3
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


# ============================================================
# Environment
# ============================================================

LOCALSTACK_ENDPOINT = os.getenv(
    "LOCALSTACK_ENDPOINT",
    "http://localhost:4566",
)

AWS_REGION = os.getenv(
    "AWS_REGION",
    "ap-northeast-1",
)

PROJECT_NAME = os.getenv(
    "PROJECT_NAME",
    "aws-enterprise-lab",
)

ENVIRONMENT = os.getenv(
    "ENVIRONMENT",
    "localstack",
)

CLOUDWATCH_ENABLED = (
    os.getenv(
        "CLOUDWATCH_ENABLED",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected Names
# ============================================================

CLOUDWATCH_LOG_GROUP_NAME = os.getenv(
    "CLOUDWATCH_LOG_GROUP_NAME",
)

EXPECTED_LOG_GROUP_NAME = (
    CLOUDWATCH_LOG_GROUP_NAME
    if CLOUDWATCH_LOG_GROUP_NAME
    else f"/aws/{PROJECT_NAME}/{ENVIRONMENT}/application"
)

CLOUDWATCH_ALARM_NAME = os.getenv(
    "CLOUDWATCH_ALARM_NAME",
)

EXPECTED_ALARM_NAME = (
    CLOUDWATCH_ALARM_NAME
    if CLOUDWATCH_ALARM_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-alarm"
)

CLOUDWATCH_DASHBOARD_NAME = os.getenv(
    "CLOUDWATCH_DASHBOARD_NAME",
)

EXPECTED_DASHBOARD_NAME = (
    CLOUDWATCH_DASHBOARD_NAME
    if CLOUDWATCH_DASHBOARD_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-dashboard"
)


# ============================================================
# Expected Log Group Configuration
# ============================================================

EXPECTED_LOG_RETENTION = int(
    os.getenv(
        "CLOUDWATCH_LOG_RETENTION_IN_DAYS",
        "30",
    )
)

EXPECTED_LOG_KMS_KEY_ID = (
    os.getenv(
        "CLOUDWATCH_LOG_KMS_KEY_ID",
        "",
    )
    or None
)


# ============================================================
# Expected Alarm Configuration
# ============================================================

EXPECTED_ALARM_ENABLED = (
    os.getenv(
        "CLOUDWATCH_ALARM_ENABLED",
        "true",
    ).lower()
    == "true"
)

EXPECTED_ALARM_DESCRIPTION = os.getenv(
    "CLOUDWATCH_ALARM_DESCRIPTION",
    "Managed by Terraform",
)

EXPECTED_ALARM_NAMESPACE = os.getenv(
    "CLOUDWATCH_ALARM_NAMESPACE",
    "Custom/AWSEnterpriseLab",
)

EXPECTED_ALARM_METRIC_NAME = os.getenv(
    "CLOUDWATCH_ALARM_METRIC_NAME",
    "HealthStatus",
)

EXPECTED_ALARM_STATISTIC = os.getenv(
    "CLOUDWATCH_ALARM_STATISTIC",
    "Average",
)

EXPECTED_ALARM_PERIOD = int(
    os.getenv(
        "CLOUDWATCH_ALARM_PERIOD",
        "60",
    )
)

EXPECTED_ALARM_EVALUATION_PERIODS = int(
    os.getenv(
        "CLOUDWATCH_ALARM_EVALUATION_PERIODS",
        "1",
    )
)

EXPECTED_ALARM_DATAPOINTS = int(
    os.getenv(
        "CLOUDWATCH_ALARM_DATAPOINTS_TO_ALARM",
        "1",
    )
)

EXPECTED_ALARM_THRESHOLD = float(
    os.getenv(
        "CLOUDWATCH_ALARM_THRESHOLD",
        "1",
    )
)

EXPECTED_ALARM_COMPARISON_OPERATOR = os.getenv(
    "CLOUDWATCH_ALARM_COMPARISON_OPERATOR",
    "GreaterThanOrEqualToThreshold",
)

EXPECTED_ALARM_TREAT_MISSING_DATA = os.getenv(
    "CLOUDWATCH_ALARM_TREAT_MISSING_DATA",
    "missing",
)

EXPECTED_ALARM_UNIT = (
    os.getenv(
        "CLOUDWATCH_ALARM_UNIT",
        "",
    )
    or None
)

EXPECTED_ALARM_ACTIONS_ENABLED = (
    os.getenv(
        "CLOUDWATCH_ALARM_ACTIONS_ENABLED",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected Dimensions
# ============================================================

RAW_DIMENSIONS = os.getenv(
    "CLOUDWATCH_ALARM_DIMENSIONS_JSON",
    "{}",
)

try:
    EXPECTED_ALARM_DIMENSIONS = json.loads(
        RAW_DIMENSIONS
    )
except json.JSONDecodeError as error:
    print(
        "[ERROR] Invalid "
        "CLOUDWATCH_ALARM_DIMENSIONS_JSON:"
    )
    print(
        f"        {error}"
    )
    sys.exit(1)

if not isinstance(
    EXPECTED_ALARM_DIMENSIONS,
    dict,
):
    print(
        "[ERROR] CLOUDWATCH_ALARM_DIMENSIONS_JSON "
        "must contain a JSON object."
    )
    sys.exit(1)


# ============================================================
# Expected Alarm Actions
# ============================================================

def parse_csv_env(
    name: str,
) -> list[str]:
    value = os.getenv(
        name,
        "",
    )

    return [
        item.strip()
        for item in value.split(",")
        if item.strip()
    ]


EXPECTED_ALARM_ACTIONS = parse_csv_env(
    "CLOUDWATCH_ALARM_ACTIONS"
)

EXPECTED_OK_ACTIONS = parse_csv_env(
    "CLOUDWATCH_OK_ACTIONS"
)

EXPECTED_INSUFFICIENT_DATA_ACTIONS = (
    parse_csv_env(
        "CLOUDWATCH_INSUFFICIENT_DATA_ACTIONS"
    )
)


# ============================================================
# Expected Dashboard
# ============================================================

EXPECTED_DASHBOARD_ENABLED = (
    os.getenv(
        "CLOUDWATCH_DASHBOARD_ENABLED",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected Tags
# ============================================================

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_LOG_GROUP_NAME,
    "Component": "observability",
    "Service": "cloudwatch",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


# ============================================================
# Clients
# ============================================================

logs = boto3.client(
    "logs",
    region_name=AWS_REGION,
    endpoint_url=LOCALSTACK_ENDPOINT,
)

cloudwatch = boto3.client(
    "cloudwatch",
    region_name=AWS_REGION,
    endpoint_url=LOCALSTACK_ENDPOINT,
)


# ============================================================
# Result Helpers
# ============================================================

def pass_check(
    message: str,
) -> None:
    global PASS_COUNT

    PASS_COUNT += 1
    print(
        f"[PASS] {message}"
    )


def warn_check(
    message: str,
) -> None:
    global WARN_COUNT

    WARN_COUNT += 1
    print(
        f"[WARN] {message}"
    )


def fail_check(
    message: str,
) -> None:
    global FAIL_COUNT

    FAIL_COUNT += 1
    print(
        f"[FAIL] {message}"
    )


def check_equal(
    label: str,
    actual: Any,
    expected: Any,
) -> None:
    if actual == expected:
        pass_check(
            f"{label}: {actual}"
        )
        return

    fail_check(
        f"{label}: "
        f"expected={expected!r}, "
        f"actual={actual!r}"
    )


# ============================================================
# API Helpers - Logs
# ============================================================

def get_log_group() -> dict[str, Any] | None:
    next_token = None

    while True:
        request: dict[str, Any] = {
            "logGroupNamePrefix": (
                EXPECTED_LOG_GROUP_NAME
            ),
        }

        if next_token:
            request[
                "nextToken"
            ] = next_token

        response = logs.describe_log_groups(
            **request
        )

        for log_group in response.get(
            "logGroups",
            [],
        ):
            if (
                log_group.get(
                    "logGroupName"
                )
                == EXPECTED_LOG_GROUP_NAME
            ):
                return log_group

        next_token = response.get(
            "nextToken"
        )

        if not next_token:
            break

    return None


def get_log_group_tags(
    log_group_name: str,
) -> dict[str, str]:
    response = logs.list_tags_log_group(
        logGroupName=log_group_name,
    )

    return response.get(
        "tags",
        {},
    )


# ============================================================
# API Helpers - Alarm
# ============================================================

def get_alarm() -> dict[str, Any] | None:
    response = cloudwatch.describe_alarms(
        AlarmNames=[
            EXPECTED_ALARM_NAME,
        ],
    )

    alarms = response.get(
        "MetricAlarms",
        [],
    )

    if not alarms:
        return None

    return alarms[0]


# ============================================================
# API Helpers - Dashboard
# ============================================================

def get_dashboard() -> dict[str, Any] | None:
    try:
        return cloudwatch.get_dashboard(
            DashboardName=EXPECTED_DASHBOARD_NAME,
        )

    except ClientError as error:
        code = error.response.get(
            "Error",
            {},
        ).get(
            "Code",
            "",
        )

        if code in {
            "ResourceNotFound",
            "ResourceNotFoundException",
        }:
            return None

        raise


# ============================================================
# Validate Log Group
# ============================================================

def validate_log_group() -> None:
    print()
    print("LOG GROUP")
    print("-" * 70)

    log_group = get_log_group()

    if not log_group:
        fail_check(
            "Expected Log Group does not exist: "
            f"{EXPECTED_LOG_GROUP_NAME}"
        )
        return

    check_equal(
        "Log Group name",
        log_group.get(
            "logGroupName"
        ),
        EXPECTED_LOG_GROUP_NAME,
    )

    arn = log_group.get(
        "arn"
    )

    if arn:
        pass_check(
            f"Log Group ARN exists: {arn}"
        )
    else:
        fail_check(
            "Log Group ARN is missing."
        )

    actual_retention = log_group.get(
        "retentionInDays"
    )

    if EXPECTED_LOG_RETENTION == 0:
        if actual_retention is None:
            pass_check(
                "Log retention: Never expire"
            )
        else:
            fail_check(
                "Log retention should be unlimited, "
                f"actual={actual_retention}"
            )

    else:
        check_equal(
            "Log retention",
            actual_retention,
            EXPECTED_LOG_RETENTION,
        )

    actual_kms = log_group.get(
        "kmsKeyId"
    )

    if EXPECTED_LOG_KMS_KEY_ID:
        check_equal(
            "Log Group KMS key",
            actual_kms,
            EXPECTED_LOG_KMS_KEY_ID,
        )
    else:
        if actual_kms:
            warn_check(
                "No KMS key expected but "
                f"kmsKeyId was returned: {actual_kms}"
            )
        else:
            pass_check(
                "No customer-managed KMS key configured."
            )

    validate_log_group_tags(
        log_group
    )


# ============================================================
# Validate Log Group Tags
# ============================================================

def validate_log_group_tags(
    log_group: dict[str, Any],
) -> None:
    print()
    print("LOG GROUP TAGS")
    print("-" * 70)

    name = log_group.get(
        "logGroupName"
    )

    if not name:
        fail_check(
            "Cannot inspect Log Group tags "
            "because the name is missing."
        )
        return

    try:
        tags = get_log_group_tags(
            name
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "CloudWatch Logs tag API "
            f"is unavailable: {error}"
        )
        return

    for key, expected_value in (
        EXPECTED_TAGS.items()
    ):
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"Tag {key}: {actual_value}"
            )
        else:
            fail_check(
                f"Tag {key}: "
                f"expected={expected_value!r}, "
                f"actual={actual_value!r}"
            )


# ============================================================
# Alarm Dimension Helper
# ============================================================

def dimensions_to_dict(
    dimensions: list[dict[str, str]],
) -> dict[str, str]:
    return {
        item.get("Name"): item.get("Value")
        for item in dimensions
        if item.get("Name")
    }


# ============================================================
# Validate Alarm
# ============================================================

def validate_alarm() -> None:
    print()
    print("METRIC ALARM")
    print("-" * 70)

    alarm = get_alarm()

    if not EXPECTED_ALARM_ENABLED:
        if alarm is None:
            pass_check(
                "Metric Alarm is disabled "
                "and does not exist."
            )
        else:
            fail_check(
                "Metric Alarm should be disabled "
                "but still exists."
            )

        return

    if alarm is None:
        fail_check(
            "Expected Metric Alarm does not exist: "
            f"{EXPECTED_ALARM_NAME}"
        )
        return

    check_equal(
        "Alarm name",
        alarm.get(
            "AlarmName"
        ),
        EXPECTED_ALARM_NAME,
    )

    arn = alarm.get(
        "AlarmArn"
    )

    if arn:
        pass_check(
            f"Alarm ARN exists: {arn}"
        )
    else:
        fail_check(
            "Alarm ARN is missing."
        )

    check_equal(
        "Alarm description",
        alarm.get(
            "AlarmDescription"
        ),
        EXPECTED_ALARM_DESCRIPTION,
    )

    check_equal(
        "Namespace",
        alarm.get(
            "Namespace"
        ),
        EXPECTED_ALARM_NAMESPACE,
    )

    check_equal(
        "Metric name",
        alarm.get(
            "MetricName"
        ),
        EXPECTED_ALARM_METRIC_NAME,
    )

    check_equal(
        "Statistic",
        alarm.get(
            "Statistic"
        ),
        EXPECTED_ALARM_STATISTIC,
    )

    check_equal(
        "Period",
        alarm.get(
            "Period"
        ),
        EXPECTED_ALARM_PERIOD,
    )

    check_equal(
        "Evaluation periods",
        alarm.get(
            "EvaluationPeriods"
        ),
        EXPECTED_ALARM_EVALUATION_PERIODS,
    )

    check_equal(
        "Datapoints to alarm",
        alarm.get(
            "DatapointsToAlarm"
        ),
        EXPECTED_ALARM_DATAPOINTS,
    )

    actual_threshold = alarm.get(
        "Threshold"
    )

    if actual_threshold is not None:
        actual_threshold = float(
            actual_threshold
        )

    check_equal(
        "Threshold",
        actual_threshold,
        EXPECTED_ALARM_THRESHOLD,
    )

    check_equal(
        "Comparison operator",
        alarm.get(
            "ComparisonOperator"
        ),
        EXPECTED_ALARM_COMPARISON_OPERATOR,
    )

    check_equal(
        "Treat missing data",
        alarm.get(
            "TreatMissingData"
        ),
        EXPECTED_ALARM_TREAT_MISSING_DATA,
    )

    check_equal(
        "Actions enabled",
        alarm.get(
            "ActionsEnabled"
        ),
        EXPECTED_ALARM_ACTIONS_ENABLED,
    )

    actual_unit = alarm.get(
        "Unit"
    )

    check_equal(
        "Unit",
        actual_unit,
        EXPECTED_ALARM_UNIT,
    )

    actual_dimensions = dimensions_to_dict(
        alarm.get(
            "Dimensions",
            [],
        )
    )

    check_equal(
        "Dimensions",
        actual_dimensions,
        EXPECTED_ALARM_DIMENSIONS,
    )

    validate_alarm_actions(
        alarm
    )

    validate_alarm_state(
        alarm
    )


# ============================================================
# Validate Alarm Actions
# ============================================================

def validate_alarm_actions(
    alarm: dict[str, Any],
) -> None:
    print()
    print("ALARM ACTIONS")
    print("-" * 70)

    actual_alarm_actions = sorted(
        alarm.get(
            "AlarmActions",
            [],
        )
    )

    actual_ok_actions = sorted(
        alarm.get(
            "OKActions",
            [],
        )
    )

    actual_insufficient_actions = sorted(
        alarm.get(
            "InsufficientDataActions",
            [],
        )
    )

    check_equal(
        "ALARM actions",
        actual_alarm_actions,
        sorted(
            EXPECTED_ALARM_ACTIONS
        ),
    )

    check_equal(
        "OK actions",
        actual_ok_actions,
        sorted(
            EXPECTED_OK_ACTIONS
        ),
    )

    check_equal(
        "INSUFFICIENT_DATA actions",
        actual_insufficient_actions,
        sorted(
            EXPECTED_INSUFFICIENT_DATA_ACTIONS
        ),
    )


# ============================================================
# Validate Alarm State
# ============================================================

def validate_alarm_state(
    alarm: dict[str, Any],
) -> None:
    print()
    print("ALARM STATE")
    print("-" * 70)

    state = alarm.get(
        "StateValue"
    )

    if state in {
        "OK",
        "ALARM",
        "INSUFFICIENT_DATA",
    }:
        pass_check(
            f"Alarm state is valid: {state}"
        )
    else:
        fail_check(
            f"Invalid Alarm state: {state!r}"
        )

    reason = alarm.get(
        "StateReason"
    )

    if reason:
        pass_check(
            "Alarm state reason exists."
        )
    else:
        warn_check(
            "Alarm StateReason was not returned."
        )


# ============================================================
# Validate Dashboard
# ============================================================

def validate_dashboard() -> None:
    print()
    print("DASHBOARD")
    print("-" * 70)

    try:
        dashboard = get_dashboard()

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        if EXPECTED_DASHBOARD_ENABLED:
            warn_check(
                "Dashboard API is unavailable "
                f"or unsupported: {error}"
            )
        else:
            pass_check(
                "Dashboard is disabled."
            )

        return

    if not EXPECTED_DASHBOARD_ENABLED:
        if dashboard is None:
            pass_check(
                "Dashboard is disabled "
                "and does not exist."
            )
        else:
            fail_check(
                "Dashboard should be disabled "
                "but still exists."
            )

        return

    if dashboard is None:
        fail_check(
            "Expected Dashboard does not exist: "
            f"{EXPECTED_DASHBOARD_NAME}"
        )
        return

    check_equal(
        "Dashboard name",
        dashboard.get(
            "DashboardName"
        ),
        EXPECTED_DASHBOARD_NAME,
    )

    dashboard_arn = dashboard.get(
        "DashboardArn"
    )

    if dashboard_arn:
        pass_check(
            f"Dashboard ARN exists: {dashboard_arn}"
        )
    else:
        warn_check(
            "DashboardArn was not returned."
        )

    body = dashboard.get(
        "DashboardBody"
    )

    if not body:
        fail_check(
            "Dashboard body is empty."
        )
        return

    try:
        document = json.loads(
            body
        )

    except json.JSONDecodeError as error:
        fail_check(
            "Dashboard body is not valid JSON: "
            f"{error}"
        )
        return

    widgets = document.get(
        "widgets",
        []
    )

    if not isinstance(
        widgets,
        list,
    ):
        fail_check(
            "Dashboard widgets is not a list."
        )
        return

    if len(widgets) >= 2:
        pass_check(
            f"Dashboard widget count: {len(widgets)}"
        )
    else:
        fail_check(
            "Expected at least 2 dashboard widgets, "
            f"actual={len(widgets)}"
        )

    validate_dashboard_widgets(
        widgets
    )


# ============================================================
# Validate Dashboard Widgets
# ============================================================

def validate_dashboard_widgets(
    widgets: list[dict[str, Any]],
) -> None:
    metric_widgets = [
        widget
        for widget in widgets
        if widget.get(
            "type"
        ) == "metric"
    ]

    log_widgets = [
        widget
        for widget in widgets
        if widget.get(
            "type"
        ) == "log"
    ]

    if metric_widgets:
        pass_check(
            f"Metric widget exists: "
            f"{len(metric_widgets)}"
        )
    else:
        fail_check(
            "Dashboard metric widget is missing."
        )

    if log_widgets:
        pass_check(
            f"Log widget exists: "
            f"{len(log_widgets)}"
        )
    else:
        fail_check(
            "Dashboard log widget is missing."
        )

    if metric_widgets:
        properties = metric_widgets[
            0
        ].get(
            "properties",
            {},
        )

        metrics = properties.get(
            "metrics",
            [],
        )

        if metrics:
            pass_check(
                "Metric widget contains metrics."
            )
        else:
            fail_check(
                "Metric widget has no metrics."
            )

    if log_widgets:
        properties = log_widgets[
            0
        ].get(
            "properties",
            {},
        )

        query = properties.get(
            "query",
            "",
        )

        if EXPECTED_LOG_GROUP_NAME in query:
            pass_check(
                "Log widget references expected "
                "Log Group."
            )
        else:
            fail_check(
                "Log widget does not reference "
                "the expected Log Group."
            )


# ============================================================
# Validate Metric Discovery
# ============================================================

def validate_metric_discovery() -> None:
    print()
    print("METRIC DISCOVERY")
    print("-" * 70)

    request: dict[str, Any] = {
        "Namespace": EXPECTED_ALARM_NAMESPACE,
        "MetricName": EXPECTED_ALARM_METRIC_NAME,
    }

    if EXPECTED_ALARM_DIMENSIONS:
        request[
            "Dimensions"
        ] = [
            {
                "Name": key,
                "Value": value,
            }
            for key, value in (
                EXPECTED_ALARM_DIMENSIONS.items()
            )
        ]

    try:
        response = cloudwatch.list_metrics(
            **request
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        warn_check(
            "Metric discovery API failed: "
            f"{error}"
        )
        return

    metrics = response.get(
        "Metrics",
        [],
    )

    if metrics:
        pass_check(
            f"Matching metrics found: {len(metrics)}"
        )
    else:
        warn_check(
            "No matching metric data currently exists. "
            "This is normal before PutMetricData."
        )


# ============================================================
# Summary
# ============================================================

def print_summary() -> None:
    print()
    print("=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)

    print(
        f"PASS : {PASS_COUNT}"
    )

    print(
        f"WARN : {WARN_COUNT}"
    )

    print(
        f"FAIL : {FAIL_COUNT}"
    )

    print("=" * 70)

    if FAIL_COUNT == 0:
        print(
            "[PASS] CloudWatch validation successful."
        )
    else:
        print(
            "[FAIL] CloudWatch validation failed."
        )


# ============================================================
# Main
# ============================================================

def main() -> int:
    print("=" * 70)
    print("CLOUDWATCH VALIDATION")
    print("=" * 70)

    print()

    print(
        f"Endpoint:     {LOCALSTACK_ENDPOINT}"
    )

    print(
        f"Region:       {AWS_REGION}"
    )

    print(
        f"Project:      {PROJECT_NAME}"
    )

    print(
        f"Environment:  {ENVIRONMENT}"
    )

    print(
        f"Log Group:    {EXPECTED_LOG_GROUP_NAME}"
    )

    print(
        f"Alarm:        {EXPECTED_ALARM_NAME}"
    )

    print(
        f"Dashboard:    {EXPECTED_DASHBOARD_NAME}"
    )

    if not CLOUDWATCH_ENABLED:
        print()
        pass_check(
            "CloudWatch is disabled."
        )

        print_summary()

        return 0

    try:
        validate_log_group()

        validate_alarm()

        validate_dashboard()

        validate_metric_discovery()

    except ClientError as error:
        error_info = error.response.get(
            "Error",
            {},
        )

        fail_check(
            "CloudWatch API request failed: "
            f"{error_info.get('Code', 'Unknown')} - "
            f"{error_info.get('Message', str(error))}"
        )

    except BotoCoreError as error:
        fail_check(
            f"AWS SDK error: {error}"
        )

    except Exception as error:
        fail_check(
            "Unexpected validation error: "
            f"{type(error).__name__}: {error}"
        )

    print_summary()

    return (
        0
        if FAIL_COUNT == 0
        else 1
    )


if __name__ == "__main__":
    sys.exit(
        main()
    )