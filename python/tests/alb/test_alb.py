import os

import boto3
import pytest


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

EXPECTED_ALB_NAME = (
    f"{PROJECT_NAME}-{ENVIRONMENT}-alb"
)

EXPECTED_TARGET_GROUP_NAME = (
    f"{PROJECT_NAME}-{ENVIRONMENT}-app-tg"
)

EXPECTED_LISTENER_PORT = 80
EXPECTED_LISTENER_PROTOCOL = "HTTP"

EXPECTED_TARGET_PORT = 80
EXPECTED_TARGET_PROTOCOL = "HTTP"
EXPECTED_TARGET_TYPE = "instance"

EXPECTED_HEALTH_CHECK_PROTOCOL = "HTTP"
EXPECTED_HEALTH_CHECK_PATH = "/"
EXPECTED_HEALTH_CHECK_INTERVAL = 30
EXPECTED_HEALTH_CHECK_TIMEOUT = 5
EXPECTED_HEALTHY_THRESHOLD = 2
EXPECTED_UNHEALTHY_THRESHOLD = 3


@pytest.fixture(scope="session")
def elbv2_client():
    return boto3.client(
        "elbv2",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


@pytest.fixture(scope="session")
def load_balancer(
    elbv2_client,
):
    response = elbv2_client.describe_load_balancers(
        Names=[
            EXPECTED_ALB_NAME,
        ],
    )

    load_balancers = response.get(
        "LoadBalancers",
        [],
    )

    assert load_balancers, (
        f"ALB not found: {EXPECTED_ALB_NAME}"
    )

    assert len(load_balancers) == 1

    return load_balancers[0]


@pytest.fixture(scope="session")
def target_groups(
    elbv2_client,
    load_balancer,
):
    response = elbv2_client.describe_target_groups(
        LoadBalancerArn=load_balancer[
            "LoadBalancerArn"
        ],
    )

    target_groups = response.get(
        "TargetGroups",
        [],
    )

    assert target_groups, (
        "No target groups found for ALB"
    )

    return target_groups


@pytest.fixture(scope="session")
def target_group(
    target_groups,
):
    assert len(target_groups) == 1, (
        "Expected exactly one target group, "
        f"found {len(target_groups)}"
    )

    return target_groups[0]


@pytest.fixture(scope="session")
def listeners(
    elbv2_client,
    load_balancer,
):
    response = elbv2_client.describe_listeners(
        LoadBalancerArn=load_balancer[
            "LoadBalancerArn"
        ],
    )

    listeners = response.get(
        "Listeners",
        [],
    )

    assert listeners, (
        "No listeners found for ALB"
    )

    return listeners


@pytest.fixture(scope="session")
def listener(
    listeners,
):
    assert len(listeners) == 1, (
        "Expected exactly one listener, "
        f"found {len(listeners)}"
    )

    return listeners[0]


@pytest.fixture(scope="session")
def target_health(
    elbv2_client,
    target_group,
):
    response = elbv2_client.describe_target_health(
        TargetGroupArn=target_group[
            "TargetGroupArn"
        ],
    )

    return response.get(
        "TargetHealthDescriptions",
        [],
    )


@pytest.fixture(scope="session")
def alb_tags(
    elbv2_client,
    load_balancer,
):
    response = elbv2_client.describe_tags(
        ResourceArns=[
            load_balancer[
                "LoadBalancerArn"
            ],
        ],
    )

    descriptions = response.get(
        "TagDescriptions",
        [],
    )

    assert descriptions

    return {
        tag["Key"]: tag["Value"]
        for tag in descriptions[0].get(
            "Tags",
            [],
        )
    }


def test_alb_name(
    load_balancer,
):
    assert (
        load_balancer["LoadBalancerName"]
        == EXPECTED_ALB_NAME
    )


def test_alb_type(
    load_balancer,
):
    assert (
        load_balancer["Type"]
        == "application"
    )


def test_alb_scheme(
    load_balancer,
):
    assert (
        load_balancer["Scheme"]
        == "internet-facing"
    )


def test_alb_state(
    load_balancer,
):
    assert (
        load_balancer["State"]["Code"]
        == "active"
    )


def test_alb_has_vpc(
    load_balancer,
):
    assert load_balancer.get(
        "VpcId"
    )


def test_alb_spans_two_subnets(
    load_balancer,
):
    availability_zones = load_balancer.get(
        "AvailabilityZones",
        [],
    )

    assert len(availability_zones) >= 2


def test_alb_spans_two_availability_zones(
    load_balancer,
):
    availability_zones = load_balancer.get(
        "AvailabilityZones",
        [],
    )

    zone_names = {
        zone.get("ZoneName")
        for zone in availability_zones
    }

    assert len(zone_names) >= 2


def test_alb_has_security_group(
    load_balancer,
):
    assert load_balancer.get(
        "SecurityGroups"
    )


def test_alb_has_dns_name(
    load_balancer,
):
    assert load_balancer.get(
        "DNSName"
    )


def test_target_group_name(
    target_group,
):
    assert (
        target_group["TargetGroupName"]
        == EXPECTED_TARGET_GROUP_NAME
    )


def test_target_group_protocol(
    target_group,
):
    assert (
        target_group["Protocol"]
        == EXPECTED_TARGET_PROTOCOL
    )


def test_target_group_port(
    target_group,
):
    assert (
        target_group["Port"]
        == EXPECTED_TARGET_PORT
    )


def test_target_group_type(
    target_group,
):
    assert (
        target_group["TargetType"]
        == EXPECTED_TARGET_TYPE
    )


def test_target_group_same_vpc_as_alb(
    target_group,
    load_balancer,
):
    assert (
        target_group["VpcId"]
        == load_balancer["VpcId"]
    )


def test_health_check_enabled(
    target_group,
):
    assert (
        target_group["HealthCheckEnabled"]
        is True
    )


def test_health_check_protocol(
    target_group,
):
    assert (
        target_group["HealthCheckProtocol"]
        == EXPECTED_HEALTH_CHECK_PROTOCOL
    )


def test_health_check_path(
    target_group,
):
    assert (
        target_group["HealthCheckPath"]
        == EXPECTED_HEALTH_CHECK_PATH
    )


def test_health_check_interval(
    target_group,
):
    assert (
        target_group[
            "HealthCheckIntervalSeconds"
        ]
        == EXPECTED_HEALTH_CHECK_INTERVAL
    )


def test_health_check_timeout(
    target_group,
):
    assert (
        target_group[
            "HealthCheckTimeoutSeconds"
        ]
        == EXPECTED_HEALTH_CHECK_TIMEOUT
    )


def test_healthy_threshold(
    target_group,
):
    assert (
        target_group[
            "HealthyThresholdCount"
        ]
        == EXPECTED_HEALTHY_THRESHOLD
    )


def test_unhealthy_threshold(
    target_group,
):
    assert (
        target_group[
            "UnhealthyThresholdCount"
        ]
        == EXPECTED_UNHEALTHY_THRESHOLD
    )


def test_two_targets_registered(
    target_health,
):
    assert len(target_health) >= 2


def test_target_ids_exist(
    target_health,
):
    for target in target_health:
        assert target.get(
            "Target",
            {},
        ).get(
            "Id"
        )


def test_targets_use_expected_port(
    target_health,
):
    for target in target_health:
        assert (
            target["Target"]["Port"]
            == EXPECTED_TARGET_PORT
        )


def test_target_health_state_is_valid(
    target_health,
):
    valid_states = {
        "initial",
        "healthy",
        "unhealthy",
        "unused",
        "draining",
        "unavailable",
    }

    for target in target_health:
        state = target.get(
            "TargetHealth",
            {},
        ).get(
            "State"
        )

        assert state in valid_states


def test_listener_port(
    listener,
):
    assert (
        listener["Port"]
        == EXPECTED_LISTENER_PORT
    )


def test_listener_protocol(
    listener,
):
    assert (
        listener["Protocol"]
        == EXPECTED_LISTENER_PROTOCOL
    )


def test_listener_has_default_action(
    listener,
):
    assert listener.get(
        "DefaultActions"
    )


def test_listener_action_is_forward(
    listener,
):
    default_actions = listener[
        "DefaultActions"
    ]

    forward_actions = [
        action
        for action in default_actions
        if action.get("Type") == "forward"
    ]

    assert forward_actions


def test_listener_forwards_to_target_group(
    listener,
    target_group,
):
    default_actions = listener[
        "DefaultActions"
    ]

    forward_actions = [
        action
        for action in default_actions
        if action.get("Type") == "forward"
    ]

    assert forward_actions

    assert (
        forward_actions[0].get(
            "TargetGroupArn"
        )
        == target_group["TargetGroupArn"]
    )


def test_project_tag(
    alb_tags,
):
    assert (
        alb_tags.get("Project")
        == PROJECT_NAME
    )


def test_environment_tag(
    alb_tags,
):
    assert (
        alb_tags.get("Environment")
        == ENVIRONMENT
    )


def test_component_tag(
    alb_tags,
):
    assert (
        alb_tags.get("Component")
        == "load-balancer"
    )


def test_service_tag(
    alb_tags,
):
    assert (
        alb_tags.get("Service")
        == "alb"
    )


def test_tier_tag(
    alb_tags,
):
    assert (
        alb_tags.get("Tier")
        == "public"
    )