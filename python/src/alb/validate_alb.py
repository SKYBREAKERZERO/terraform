import os
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


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

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
}


PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(message):
    global PASS_COUNT

    PASS_COUNT += 1
    print(f"[PASS] {message}")


def warn_check(message):
    global WARN_COUNT

    WARN_COUNT += 1
    print(f"[WARN] {message}")


def fail_check(message):
    global FAIL_COUNT

    FAIL_COUNT += 1
    print(f"[FAIL] {message}")


def create_elbv2_client():
    return boto3.client(
        "elbv2",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


def get_load_balancer(client):
    response = client.describe_load_balancers(
        Names=[
            EXPECTED_ALB_NAME,
        ],
    )

    load_balancers = response.get(
        "LoadBalancers",
        [],
    )

    if not load_balancers:
        return None

    return load_balancers[0]


def get_target_groups(
    client,
    load_balancer_arn,
):
    response = client.describe_target_groups(
        LoadBalancerArn=load_balancer_arn,
    )

    return response.get(
        "TargetGroups",
        [],
    )


def get_listeners(
    client,
    load_balancer_arn,
):
    response = client.describe_listeners(
        LoadBalancerArn=load_balancer_arn,
    )

    return response.get(
        "Listeners",
        [],
    )


def get_target_health(
    client,
    target_group_arn,
):
    response = client.describe_target_health(
        TargetGroupArn=target_group_arn,
    )

    return response.get(
        "TargetHealthDescriptions",
        [],
    )


def get_tags(
    client,
    resource_arn,
):
    response = client.describe_tags(
        ResourceArns=[
            resource_arn,
        ],
    )

    descriptions = response.get(
        "TagDescriptions",
        [],
    )

    if not descriptions:
        return {}

    return {
        tag["Key"]: tag["Value"]
        for tag in descriptions[0].get(
            "Tags",
            [],
        )
    }


def validate_load_balancer(load_balancer):
    if (
        load_balancer.get("LoadBalancerName")
        == EXPECTED_ALB_NAME
    ):
        pass_check(
            f"ALB name is {EXPECTED_ALB_NAME}"
        )
    else:
        fail_check(
            "Unexpected ALB name: "
            f"{load_balancer.get('LoadBalancerName')}"
        )

    if load_balancer.get("Type") == "application":
        pass_check(
            "Load balancer type is application"
        )
    else:
        fail_check(
            "Load balancer type is not application"
        )

    if load_balancer.get("Scheme") == "internet-facing":
        pass_check(
            "ALB scheme is internet-facing"
        )
    else:
        fail_check(
            "ALB scheme is not internet-facing: "
            f"{load_balancer.get('Scheme')}"
        )

    state = load_balancer.get(
        "State",
        {},
    ).get(
        "Code"
    )

    if state == "active":
        pass_check(
            "ALB state is active"
        )
    elif state:
        warn_check(
            f"ALB state is {state}"
        )
    else:
        warn_check(
            "ALB state was not returned"
        )

    vpc_id = load_balancer.get(
        "VpcId"
    )

    if vpc_id:
        pass_check(
            f"ALB has VPC ID {vpc_id}"
        )
    else:
        fail_check(
            "ALB has no VPC ID"
        )

    availability_zones = load_balancer.get(
        "AvailabilityZones",
        [],
    )

    if len(availability_zones) >= 2:
        pass_check(
            "ALB spans at least two subnets/AZs"
        )
    else:
        fail_check(
            "ALB does not span at least two subnets/AZs"
        )

    security_groups = load_balancer.get(
        "SecurityGroups",
        [],
    )

    if security_groups:
        pass_check(
            "ALB has at least one security group"
        )
    else:
        fail_check(
            "ALB has no security groups"
        )

    dns_name = load_balancer.get(
        "DNSName"
    )

    if dns_name:
        pass_check(
            f"ALB DNS name exists: {dns_name}"
        )
    else:
        fail_check(
            "ALB DNS name is missing"
        )


def validate_target_group(
    target_group,
):
    if (
        target_group.get("TargetGroupName")
        == EXPECTED_TARGET_GROUP_NAME
    ):
        pass_check(
            "Target group name is correct"
        )
    else:
        fail_check(
            "Unexpected target group name: "
            f"{target_group.get('TargetGroupName')}"
        )

    if (
        target_group.get("Protocol")
        == EXPECTED_TARGET_PROTOCOL
    ):
        pass_check(
            "Target group protocol is HTTP"
        )
    else:
        fail_check(
            "Unexpected target group protocol: "
            f"{target_group.get('Protocol')}"
        )

    if (
        target_group.get("Port")
        == EXPECTED_TARGET_PORT
    ):
        pass_check(
            "Target group port is 80"
        )
    else:
        fail_check(
            "Unexpected target group port: "
            f"{target_group.get('Port')}"
        )

    if (
        target_group.get("TargetType")
        == EXPECTED_TARGET_TYPE
    ):
        pass_check(
            "Target type is instance"
        )
    else:
        fail_check(
            "Unexpected target type: "
            f"{target_group.get('TargetType')}"
        )

    if (
        target_group.get(
            "HealthCheckEnabled"
        )
        is True
    ):
        pass_check(
            "Health check is enabled"
        )
    else:
        fail_check(
            "Health check is disabled"
        )

    if (
        target_group.get(
            "HealthCheckProtocol"
        )
        == EXPECTED_HEALTH_CHECK_PROTOCOL
    ):
        pass_check(
            "Health check protocol is HTTP"
        )
    else:
        fail_check(
            "Unexpected health check protocol: "
            f"{target_group.get('HealthCheckProtocol')}"
        )

    if (
        target_group.get(
            "HealthCheckPath"
        )
        == EXPECTED_HEALTH_CHECK_PATH
    ):
        pass_check(
            "Health check path is /"
        )
    else:
        fail_check(
            "Unexpected health check path: "
            f"{target_group.get('HealthCheckPath')}"
        )

    if (
        target_group.get(
            "HealthCheckIntervalSeconds"
        )
        == EXPECTED_HEALTH_CHECK_INTERVAL
    ):
        pass_check(
            "Health check interval is 30 seconds"
        )
    else:
        fail_check(
            "Unexpected health check interval: "
            f"{target_group.get('HealthCheckIntervalSeconds')}"
        )

    if (
        target_group.get(
            "HealthCheckTimeoutSeconds"
        )
        == EXPECTED_HEALTH_CHECK_TIMEOUT
    ):
        pass_check(
            "Health check timeout is 5 seconds"
        )
    else:
        fail_check(
            "Unexpected health check timeout: "
            f"{target_group.get('HealthCheckTimeoutSeconds')}"
        )

    if (
        target_group.get(
            "HealthyThresholdCount"
        )
        == EXPECTED_HEALTHY_THRESHOLD
    ):
        pass_check(
            "Healthy threshold is 2"
        )
    else:
        fail_check(
            "Unexpected healthy threshold: "
            f"{target_group.get('HealthyThresholdCount')}"
        )

    if (
        target_group.get(
            "UnhealthyThresholdCount"
        )
        == EXPECTED_UNHEALTHY_THRESHOLD
    ):
        pass_check(
            "Unhealthy threshold is 3"
        )
    else:
        fail_check(
            "Unexpected unhealthy threshold: "
            f"{target_group.get('UnhealthyThresholdCount')}"
        )


def validate_targets(
    targets,
):
    if len(targets) >= 2:
        pass_check(
            "At least two targets are registered"
        )
    else:
        fail_check(
            f"Expected at least two targets, found {len(targets)}"
        )

    for target in targets:
        target_info = target.get(
            "Target",
            {},
        )

        target_health = target.get(
            "TargetHealth",
            {},
        )

        target_id = target_info.get(
            "Id"
        )

        target_port = target_info.get(
            "Port"
        )

        state = target_health.get(
            "State"
        )

        if target_id:
            pass_check(
                f"Target ID exists: {target_id}"
            )
        else:
            fail_check(
                "Target ID is missing"
            )

        if target_port == EXPECTED_TARGET_PORT:
            pass_check(
                f"Target {target_id} uses port 80"
            )
        else:
            fail_check(
                f"Target {target_id} uses unexpected port "
                f"{target_port}"
            )

        if state == "healthy":
            pass_check(
                f"Target {target_id} is healthy"
            )
        elif state in {
            "initial",
            "unused",
            "unavailable",
        }:
            warn_check(
                f"Target {target_id} health state is {state}"
            )
        else:
            warn_check(
                f"Target {target_id} health state is {state}"
            )


def validate_listener(
    listener,
    expected_target_group_arn,
):
    if (
        listener.get("Port")
        == EXPECTED_LISTENER_PORT
    ):
        pass_check(
            "Listener port is 80"
        )
    else:
        fail_check(
            "Unexpected listener port: "
            f"{listener.get('Port')}"
        )

    if (
        listener.get("Protocol")
        == EXPECTED_LISTENER_PROTOCOL
    ):
        pass_check(
            "Listener protocol is HTTP"
        )
    else:
        fail_check(
            "Unexpected listener protocol: "
            f"{listener.get('Protocol')}"
        )

    default_actions = listener.get(
        "DefaultActions",
        [],
    )

    if not default_actions:
        fail_check(
            "Listener has no default actions"
        )
        return

    forward_actions = [
        action
        for action in default_actions
        if action.get("Type") == "forward"
    ]

    if forward_actions:
        pass_check(
            "Listener default action is forward"
        )
    else:
        fail_check(
            "Listener has no forward default action"
        )
        return

    action = forward_actions[0]

    target_group_arn = action.get(
        "TargetGroupArn"
    )

    if (
        target_group_arn
        == expected_target_group_arn
    ):
        pass_check(
            "Listener forwards to expected target group"
        )
    else:
        fail_check(
            "Listener forwards to unexpected target group"
        )


def validate_tags(
    client,
    resource_arn,
):
    tags = get_tags(
        client,
        resource_arn,
    )

    if not tags:
        fail_check(
            "ALB has no tags"
        )
        return

    pass_check(
        "ALB has tags"
    )

    for key, expected_value in EXPECTED_TAGS.items():
        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"Tag {key}={expected_value}"
            )
        elif actual_value is None:
            warn_check(
                f"Tag {key} is missing"
            )
        else:
            fail_check(
                f"Tag {key} expected "
                f"{expected_value}, got {actual_value}"
            )


def print_summary():
    print()
    print("=" * 70)
    print("ALB VALIDATION SUMMARY")
    print("=" * 70)

    print(
        f"PASS: {PASS_COUNT}"
    )

    print(
        f"WARN: {WARN_COUNT}"
    )

    print(
        f"FAIL: {FAIL_COUNT}"
    )


def main():
    try:
        client = create_elbv2_client()

        load_balancer = get_load_balancer(
            client
        )

        if load_balancer is None:
            fail_check(
                f"ALB not found: {EXPECTED_ALB_NAME}"
            )
            print_summary()
            return 1

        validate_load_balancer(
            load_balancer
        )

        load_balancer_arn = load_balancer[
            "LoadBalancerArn"
        ]

        target_groups = get_target_groups(
            client,
            load_balancer_arn,
        )

        if not target_groups:
            fail_check(
                "No target groups attached to ALB"
            )

            print_summary()
            return 1

        if len(target_groups) == 1:
            pass_check(
                "Exactly one target group is attached to ALB"
            )
        else:
            warn_check(
                "Expected one target group, "
                f"found {len(target_groups)}"
            )

        target_group = target_groups[0]

        validate_target_group(
            target_group
        )

        target_group_arn = target_group[
            "TargetGroupArn"
        ]

        targets = get_target_health(
            client,
            target_group_arn,
        )

        validate_targets(
            targets
        )

        listeners = get_listeners(
            client,
            load_balancer_arn,
        )

        if not listeners:
            fail_check(
                "ALB has no listeners"
            )

            print_summary()
            return 1

        if len(listeners) == 1:
            pass_check(
                "Exactly one listener exists"
            )
        else:
            warn_check(
                "Expected one listener, "
                f"found {len(listeners)}"
            )

        validate_listener(
            listeners[0],
            target_group_arn,
        )

        validate_tags(
            client,
            load_balancer_arn,
        )

    except (
        ClientError,
        BotoCoreError,
        RuntimeError,
    ) as error:
        fail_check(
            f"AWS API error: {error}"
        )

    print_summary()

    if FAIL_COUNT > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())