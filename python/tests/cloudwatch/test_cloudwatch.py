import json
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import boto3
import pytest
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

EXPECTED_DASHBOARD_ENABLED = (
    os.getenv(
        "CLOUDWATCH_DASHBOARD_ENABLED",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Dimensions
# ============================================================

RAW_DIMENSIONS = os.getenv(
    "CLOUDWATCH_ALARM_DIMENSIONS_JSON",
    "{}",
)

EXPECTED_DIMENSIONS = json.loads(
    RAW_DIMENSIONS
)

if not isinstance(
    EXPECTED_DIMENSIONS,
    dict,
):
    raise ValueError(
        "CLOUDWATCH_ALARM_DIMENSIONS_JSON "
        "must be a JSON object."
    )


# ============================================================
# Runtime Metric
# ============================================================

TEST_METRIC_VALUE = float(
    os.getenv(
        "CLOUDWATCH_TEST_METRIC_VALUE",
        "10",
    )
)

TEST_METRIC_UNIT = os.getenv(
    "CLOUDWATCH_TEST_METRIC_UNIT",
    "Count",
)

METRIC_TIMEOUT_SECONDS = int(
    os.getenv(
        "CLOUDWATCH_METRIC_TIMEOUT_SECONDS",
        "15",
    )
)

ALARM_TIMEOUT_SECONDS = int(
    os.getenv(
        "CLOUDWATCH_ALARM_TIMEOUT_SECONDS",
        "20",
    )
)


# ============================================================
# Skip
# ============================================================

pytestmark = pytest.mark.skipif(
    not CLOUDWATCH_ENABLED,
    reason="CloudWatch is disabled.",
)


# ============================================================
# Clients
# ============================================================

@pytest.fixture(scope="session")
def cloudwatch_client():
    return boto3.client(
        "cloudwatch",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


@pytest.fixture(scope="session")
def logs_client():
    return boto3.client(
        "logs",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# Resource Fixtures
# ============================================================

@pytest.fixture(scope="session")
def log_group(
    logs_client,
) -> dict[str, Any]:
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

        response = logs_client.describe_log_groups(
            **request
        )

        for group in response.get(
            "logGroups",
            [],
        ):
            if (
                group.get(
                    "logGroupName"
                )
                == EXPECTED_LOG_GROUP_NAME
            ):
                return group

        next_token = response.get(
            "nextToken"
        )

        if not next_token:
            break

    pytest.fail(
        "Expected CloudWatch Log Group "
        f"does not exist: {EXPECTED_LOG_GROUP_NAME}"
    )


@pytest.fixture(scope="session")
def alarm(
    cloudwatch_client,
) -> dict[str, Any] | None:
    response = cloudwatch_client.describe_alarms(
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
# CloudWatch Logs Tests
# ============================================================

def test_log_group_exists(
    log_group,
):
    assert (
        log_group.get(
            "logGroupName"
        )
        == EXPECTED_LOG_GROUP_NAME
    )


def test_log_group_arn_exists(
    log_group,
):
    assert log_group.get(
        "arn"
    )


def test_log_group_retention(
    log_group,
):
    actual = log_group.get(
        "retentionInDays"
    )

    if EXPECTED_LOG_RETENTION == 0:
        assert actual is None
    else:
        assert (
            actual
            == EXPECTED_LOG_RETENTION
        )


# ============================================================
# Alarm Configuration Tests
# ============================================================

def test_alarm_exists_or_disabled(
    alarm,
):
    if EXPECTED_ALARM_ENABLED:
        assert alarm is not None
    else:
        assert alarm is None


def test_alarm_name(
    alarm,
):
    if not EXPECTED_ALARM_ENABLED:
        pytest.skip(
            "Alarm is disabled."
        )

    assert alarm is not None

    assert (
        alarm.get(
            "AlarmName"
        )
        == EXPECTED_ALARM_NAME
    )


def test_alarm_metric_configuration(
    alarm,
):
    if not EXPECTED_ALARM_ENABLED:
        pytest.skip(
            "Alarm is disabled."
        )

    assert alarm is not None

    assert (
        alarm.get(
            "Namespace"
        )
        == EXPECTED_ALARM_NAMESPACE
    )

    assert (
        alarm.get(
            "MetricName"
        )
        == EXPECTED_ALARM_METRIC_NAME
    )

    assert (
        alarm.get(
            "Statistic"
        )
        == EXPECTED_ALARM_STATISTIC
    )

    assert (
        alarm.get(
            "Period"
        )
        == EXPECTED_ALARM_PERIOD
    )

    assert (
        alarm.get(
            "EvaluationPeriods"
        )
        == EXPECTED_ALARM_EVALUATION_PERIODS
    )

    assert (
        alarm.get(
            "DatapointsToAlarm"
        )
        == EXPECTED_ALARM_DATAPOINTS
    )

    assert (
        float(
            alarm.get(
                "Threshold"
            )
        )
        == EXPECTED_ALARM_THRESHOLD
    )

    assert (
        alarm.get(
            "ComparisonOperator"
        )
        == EXPECTED_ALARM_COMPARISON_OPERATOR
    )

    assert (
        alarm.get(
            "TreatMissingData"
        )
        == EXPECTED_ALARM_TREAT_MISSING_DATA
    )


def test_alarm_dimensions(
    alarm,
):
    if not EXPECTED_ALARM_ENABLED:
        pytest.skip(
            "Alarm is disabled."
        )

    assert alarm is not None

    actual_dimensions = {
        item["Name"]: item["Value"]
        for item in alarm.get(
            "Dimensions",
            [],
        )
    }

    assert (
        actual_dimensions
        == EXPECTED_DIMENSIONS
    )


# ============================================================
# Dashboard Tests
# ============================================================

def test_dashboard_exists(
    cloudwatch_client,
):
    if not EXPECTED_DASHBOARD_ENABLED:
        pytest.skip(
            "Dashboard is disabled."
        )

    try:
        response = cloudwatch_client.get_dashboard(
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
            pytest.fail(
                "Expected CloudWatch Dashboard "
                "does not exist."
            )

        raise

    assert response.get(
        "DashboardBody"
    )


def test_dashboard_contains_widgets(
    cloudwatch_client,
):
    if not EXPECTED_DASHBOARD_ENABLED:
        pytest.skip(
            "Dashboard is disabled."
        )

    response = cloudwatch_client.get_dashboard(
        DashboardName=EXPECTED_DASHBOARD_NAME,
    )

    body = json.loads(
        response[
            "DashboardBody"
        ]
    )

    widgets = body.get(
        "widgets",
        [],
    )

    assert len(
        widgets
    ) >= 2

    widget_types = {
        widget.get(
            "type"
        )
        for widget in widgets
    }

    assert "metric" in widget_types
    assert "log" in widget_types


# ============================================================
# Runtime PutMetricData
# ============================================================

@pytest.fixture(scope="session")
def runtime_metric(
    cloudwatch_client,
):
    timestamp = datetime.now(
        timezone.utc
    )

    metric_data: dict[str, Any] = {
        "MetricName": (
            EXPECTED_ALARM_METRIC_NAME
        ),
        "Timestamp": timestamp,
        "Value": TEST_METRIC_VALUE,
        "Unit": TEST_METRIC_UNIT,
    }

    if EXPECTED_DIMENSIONS:
        metric_data[
            "Dimensions"
        ] = [
            {
                "Name": key,
                "Value": value,
            }
            for key, value in (
                EXPECTED_DIMENSIONS.items()
            )
        ]

    response = cloudwatch_client.put_metric_data(
        Namespace=EXPECTED_ALARM_NAMESPACE,
        MetricData=[
            metric_data,
        ],
    )

    assert (
        response[
            "ResponseMetadata"
        ][
            "HTTPStatusCode"
        ]
        == 200
    )

    return {
        "timestamp": timestamp,
        "value": TEST_METRIC_VALUE,
    }


# ============================================================
# PutMetricData Test
# ============================================================

def test_put_metric_data(
    runtime_metric,
):
    assert runtime_metric[
        "timestamp"
    ]

    assert (
        runtime_metric[
            "value"
        ]
        == TEST_METRIC_VALUE
    )


# ============================================================
# ListMetrics
# ============================================================

def test_metric_can_be_discovered(
    cloudwatch_client,
    runtime_metric,
):
    deadline = (
        time.monotonic()
        + METRIC_TIMEOUT_SECONDS
    )

    while time.monotonic() < deadline:
        request: dict[str, Any] = {
            "Namespace": (
                EXPECTED_ALARM_NAMESPACE
            ),
            "MetricName": (
                EXPECTED_ALARM_METRIC_NAME
            ),
        }

        if EXPECTED_DIMENSIONS:
            request[
                "Dimensions"
            ] = [
                {
                    "Name": key,
                    "Value": value,
                }
                for key, value in (
                    EXPECTED_DIMENSIONS.items()
                )
            ]

        response = cloudwatch_client.list_metrics(
            **request
        )

        metrics = response.get(
            "Metrics",
            [],
        )

        if metrics:
            return

        time.sleep(
            0.5
        )

    pytest.fail(
        "Metric was not discoverable within "
        f"{METRIC_TIMEOUT_SECONDS} seconds."
    )


# ============================================================
# GetMetricStatistics
# ============================================================

def test_metric_statistics_contains_value(
    cloudwatch_client,
    runtime_metric,
):
    end_time = datetime.now(
        timezone.utc
    ) + timedelta(
        minutes=1
    )

    start_time = (
        runtime_metric[
            "timestamp"
        ]
        - timedelta(
            minutes=2
        )
    )

    request: dict[str, Any] = {
        "Namespace": (
            EXPECTED_ALARM_NAMESPACE
        ),
        "MetricName": (
            EXPECTED_ALARM_METRIC_NAME
        ),
        "StartTime": start_time,
        "EndTime": end_time,
        "Period": 60,
        "Statistics": [
            "Average",
            "Minimum",
            "Maximum",
            "Sum",
            "SampleCount",
        ],
    }

    if EXPECTED_DIMENSIONS:
        request[
            "Dimensions"
        ] = [
            {
                "Name": key,
                "Value": value,
            }
            for key, value in (
                EXPECTED_DIMENSIONS.items()
            )
        ]

    deadline = (
        time.monotonic()
        + METRIC_TIMEOUT_SECONDS
    )

    while time.monotonic() < deadline:
        response = (
            cloudwatch_client.get_metric_statistics(
                **request
            )
        )

        datapoints = response.get(
            "Datapoints",
            [],
        )

        if datapoints:
            assert any(
                float(
                    point.get(
                        "Maximum",
                        float("-inf"),
                    )
                )
                >= TEST_METRIC_VALUE
                for point in datapoints
            )

            return

        time.sleep(
            0.5
        )

    pytest.fail(
        "GetMetricStatistics returned no "
        "datapoints within "
        f"{METRIC_TIMEOUT_SECONDS} seconds."
    )


# ============================================================
# GetMetricData
# ============================================================

def test_get_metric_data_returns_value(
    cloudwatch_client,
    runtime_metric,
):
    end_time = datetime.now(
        timezone.utc
    ) + timedelta(
        minutes=1
    )

    start_time = (
        runtime_metric[
            "timestamp"
        ]
        - timedelta(
            minutes=2
        )
    )

    metric: dict[str, Any] = {
        "Namespace": (
            EXPECTED_ALARM_NAMESPACE
        ),
        "MetricName": (
            EXPECTED_ALARM_METRIC_NAME
        ),
    }

    if EXPECTED_DIMENSIONS:
        metric[
            "Dimensions"
        ] = [
            {
                "Name": key,
                "Value": value,
            }
            for key, value in (
                EXPECTED_DIMENSIONS.items()
            )
        ]

    query = {
        "Id": "smokemetric",
        "MetricStat": {
            "Metric": metric,
            "Period": 60,
            "Stat": "Average",
        },
        "ReturnData": True,
    }

    deadline = (
        time.monotonic()
        + METRIC_TIMEOUT_SECONDS
    )

    while time.monotonic() < deadline:
        response = cloudwatch_client.get_metric_data(
            MetricDataQueries=[
                query,
            ],
            StartTime=start_time,
            EndTime=end_time,
            ScanBy="TimestampDescending",
        )

        results = response.get(
            "MetricDataResults",
            [],
        )

        if results:
            values = results[
                0
            ].get(
                "Values",
                [],
            )

            if values:
                assert any(
                    float(value)
                    >= TEST_METRIC_VALUE
                    for value in values
                )

                return

        time.sleep(
            0.5
        )

    pytest.fail(
        "GetMetricData returned no metric "
        "values within "
        f"{METRIC_TIMEOUT_SECONDS} seconds."
    )


# ============================================================
# Alarm Runtime State
# ============================================================

def test_alarm_state_after_metric(
    cloudwatch_client,
    runtime_metric,
):
    if not EXPECTED_ALARM_ENABLED:
        pytest.skip(
            "Alarm is disabled."
        )

    deadline = (
        time.monotonic()
        + ALARM_TIMEOUT_SECONDS
    )

    valid_states = {
        "OK",
        "ALARM",
        "INSUFFICIENT_DATA",
    }

    while time.monotonic() < deadline:
        response = cloudwatch_client.describe_alarms(
            AlarmNames=[
                EXPECTED_ALARM_NAME,
            ],
        )

        alarms = response.get(
            "MetricAlarms",
            [],
        )

        assert alarms

        state = alarms[
            0
        ].get(
            "StateValue"
        )

        if state in valid_states:
            assert state in valid_states
            return

        time.sleep(
            0.5
        )

    pytest.fail(
        "Alarm did not return a valid state "
        f"within {ALARM_TIMEOUT_SECONDS} seconds."
    )