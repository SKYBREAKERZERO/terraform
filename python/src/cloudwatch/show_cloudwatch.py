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
# Expected Resource Names
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
# Output Helpers
# ============================================================

def print_section(
    title: str,
) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def print_value(
    label: str,
    value: Any,
    indent: int = 0,
) -> None:
    prefix = " " * indent

    if value is None:
        value = "None"

    print(
        f"{prefix}{label:<30}: {value}"
    )


def bool_text(
    value: Any,
) -> str:
    return (
        "true"
        if value
        else "false"
    )


# ============================================================
# CloudWatch Logs
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
    try:
        response = logs.list_tags_log_group(
            logGroupName=log_group_name,
        )

        return response.get(
            "tags",
            {},
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        print(
            "[WARN] Unable to retrieve "
            "Log Group tags:"
        )

        print(
            f"       {error}"
        )

        return {}


def show_log_group(
    log_group: dict[str, Any] | None,
) -> None:
    print_section(
        "CLOUDWATCH LOG GROUP"
    )

    if not log_group:
        print(
            "Log Group not found."
        )
        return

    name = log_group.get(
        "logGroupName"
    )

    print_value(
        "Log Group Name",
        name,
    )

    print_value(
        "ARN",
        log_group.get(
            "arn"
        ),
    )

    print_value(
        "Creation Time",
        log_group.get(
            "creationTime"
        ),
    )

    print_value(
        "Retention Days",
        log_group.get(
            "retentionInDays",
            "Never expire",
        ),
    )

    print_value(
        "Stored Bytes",
        log_group.get(
            "storedBytes"
        ),
    )

    print_value(
        "KMS Key ID",
        log_group.get(
            "kmsKeyId"
        ),
    )

    tags = get_log_group_tags(
        name
    )

    print()
    print(
        "Tags"
    )
    print(
        "-" * 40
    )

    if not tags:
        print_value(
            "Tags",
            "none",
            indent=2,
        )
        return

    for key in sorted(
        tags
    ):
        print_value(
            key,
            tags[key],
            indent=2,
        )


# ============================================================
# Metric Alarm
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


def show_alarm(
    alarm: dict[str, Any] | None,
) -> None:
    print_section(
        "CLOUDWATCH METRIC ALARM"
    )

    if not alarm:
        print(
            "Metric Alarm not found."
        )
        return

    print_value(
        "Alarm Name",
        alarm.get(
            "AlarmName"
        ),
    )

    print_value(
        "Alarm ARN",
        alarm.get(
            "AlarmArn"
        ),
    )

    print_value(
        "Description",
        alarm.get(
            "AlarmDescription"
        ),
    )

    print_value(
        "State",
        alarm.get(
            "StateValue"
        ),
    )

    print_value(
        "State Reason",
        alarm.get(
            "StateReason"
        ),
    )

    print_value(
        "Actions Enabled",
        bool_text(
            alarm.get(
                "ActionsEnabled",
                False,
            )
        ),
    )

    print_value(
        "Namespace",
        alarm.get(
            "Namespace"
        ),
    )

    print_value(
        "Metric Name",
        alarm.get(
            "MetricName"
        ),
    )

    print_value(
        "Statistic",
        alarm.get(
            "Statistic"
        ),
    )

    print_value(
        "Period",
        alarm.get(
            "Period"
        ),
    )

    print_value(
        "Evaluation Periods",
        alarm.get(
            "EvaluationPeriods"
        ),
    )

    print_value(
        "Datapoints To Alarm",
        alarm.get(
            "DatapointsToAlarm"
        ),
    )

    print_value(
        "Threshold",
        alarm.get(
            "Threshold"
        ),
    )

    print_value(
        "Comparison Operator",
        alarm.get(
            "ComparisonOperator"
        ),
    )

    print_value(
        "Treat Missing Data",
        alarm.get(
            "TreatMissingData"
        ),
    )

    print_value(
        "Unit",
        alarm.get(
            "Unit"
        ),
    )

    dimensions = alarm.get(
        "Dimensions",
        [],
    )

    print()
    print(
        "Dimensions"
    )
    print(
        "-" * 40
    )

    if not dimensions:
        print_value(
            "Dimensions",
            "none",
            indent=2,
        )

    else:
        for dimension in dimensions:
            print_value(
                dimension.get(
                    "Name",
                    "Unknown",
                ),
                dimension.get(
                    "Value",
                ),
                indent=2,
            )

    show_alarm_actions(
        alarm
    )


def show_alarm_actions(
    alarm: dict[str, Any],
) -> None:
    print()
    print(
        "Alarm Actions"
    )
    print(
        "-" * 40
    )

    action_groups = {
        "ALARM": alarm.get(
            "AlarmActions",
            [],
        ),
        "OK": alarm.get(
            "OKActions",
            [],
        ),
        "INSUFFICIENT_DATA": alarm.get(
            "InsufficientDataActions",
            [],
        ),
    }

    for state, actions in (
        action_groups.items()
    ):
        if not actions:
            print_value(
                state,
                "none",
                indent=2,
            )
            continue

        for action in actions:
            print_value(
                state,
                action,
                indent=2,
            )


# ============================================================
# Dashboard
# ============================================================

def get_dashboard() -> dict[str, Any] | None:
    try:
        response = cloudwatch.get_dashboard(
            DashboardName=EXPECTED_DASHBOARD_NAME,
        )

        return response

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


def show_dashboard(
    dashboard: dict[str, Any] | None,
) -> None:
    print_section(
        "CLOUDWATCH DASHBOARD"
    )

    if not dashboard:
        print(
            "Dashboard not found."
        )
        return

    print_value(
        "Dashboard Name",
        EXPECTED_DASHBOARD_NAME,
    )

    print_value(
        "Dashboard ARN",
        dashboard.get(
            "DashboardArn"
        ),
    )

    body = dashboard.get(
        "DashboardBody"
    )

    if body:
        print()
        print(
            "Dashboard Body"
        )
        print(
            "-" * 40
        )

        print(
            body
        )


# ============================================================
# Metrics
# ============================================================

def show_metrics(
    alarm: dict[str, Any] | None,
) -> None:
    print_section(
        "CLOUDWATCH METRICS"
    )

    if not alarm:
        print(
            "Alarm unavailable; metric lookup skipped."
        )
        return

    namespace = alarm.get(
        "Namespace"
    )

    metric_name = alarm.get(
        "MetricName"
    )

    if not namespace or not metric_name:
        print(
            "Namespace or MetricName is unavailable."
        )
        return

    dimensions = alarm.get(
        "Dimensions",
        [],
    )

    request: dict[str, Any] = {
        "Namespace": namespace,
        "MetricName": metric_name,
    }

    if dimensions:
        request[
            "Dimensions"
        ] = dimensions

    try:
        response = cloudwatch.list_metrics(
            **request
        )

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        print(
            "[WARN] Unable to list metrics:"
        )

        print(
            f"       {error}"
        )

        return

    metrics = response.get(
        "Metrics",
        [],
    )

    print_value(
        "Namespace",
        namespace,
    )

    print_value(
        "Metric Name",
        metric_name,
    )

    print_value(
        "Matching Metrics",
        len(metrics),
    )

    for index, metric in enumerate(
        metrics,
        start=1,
    ):
        print()
        print(
            f"Metric #{index}"
        )
        print(
            "-" * 40
        )

        print_value(
            "Namespace",
            metric.get(
                "Namespace"
            ),
            indent=2,
        )

        print_value(
            "Metric Name",
            metric.get(
                "MetricName"
            ),
            indent=2,
        )

        metric_dimensions = metric.get(
            "Dimensions",
            [],
        )

        for dimension in metric_dimensions:
            print_value(
                dimension.get(
                    "Name",
                    "Dimension",
                ),
                dimension.get(
                    "Value"
                ),
                indent=2,
            )


# ============================================================
# Main
# ============================================================

def main() -> int:
    print(
        "=" * 70
    )

    print(
        "CLOUDWATCH INFORMATION"
    )

    print(
        "=" * 70
    )

    print()

    print_value(
        "Endpoint",
        LOCALSTACK_ENDPOINT,
    )

    print_value(
        "Region",
        AWS_REGION,
    )

    print_value(
        "Project",
        PROJECT_NAME,
    )

    print_value(
        "Environment",
        ENVIRONMENT,
    )

    print_value(
        "Expected Log Group",
        EXPECTED_LOG_GROUP_NAME,
    )

    print_value(
        "Expected Alarm",
        EXPECTED_ALARM_NAME,
    )

    print_value(
        "Expected Dashboard",
        EXPECTED_DASHBOARD_NAME,
    )

    if not CLOUDWATCH_ENABLED:
        print()
        print(
            "[INFO] CloudWatch is disabled."
        )

        return 0

    try:
        log_group = get_log_group()

        alarm = get_alarm()

        dashboard = get_dashboard()

        show_log_group(
            log_group
        )

        show_alarm(
            alarm
        )

        show_dashboard(
            dashboard
        )

        show_metrics(
            alarm
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

        error_message = error_info.get(
            "Message",
            str(error),
        )

        print()
        print(
            "[ERROR] CloudWatch API request failed."
        )

        print_value(
            "Error Code",
            error_code,
        )

        print_value(
            "Message",
            error_message,
        )

        return 1

    except BotoCoreError as error:
        print()
        print(
            "[ERROR] AWS SDK error:"
        )

        print(
            f"        {error}"
        )

        return 1

    except Exception as error:
        print()
        print(
            "[ERROR] Unexpected error:"
        )

        print(
            f"        {type(error).__name__}: {error}"
        )

        return 1

    print()
    print(
        "=" * 70
    )

    print(
        "[PASS] CloudWatch information "
        "displayed successfully."
    )

    print(
        "=" * 70
    )

    return 0


if __name__ == "__main__":
    sys.exit(
        main()
    )