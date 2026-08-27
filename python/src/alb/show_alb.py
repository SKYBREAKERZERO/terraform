import os

import boto3


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


def create_elbv2_client():
    return boto3.client(
        "elbv2",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


def get_load_balancer(client):
    alb_name = f"{PROJECT_NAME}-{ENVIRONMENT}-alb"

    response = client.describe_load_balancers(
        Names=[alb_name],
    )

    load_balancers = response.get(
        "LoadBalancers",
        [],
    )

    if not load_balancers:
        raise RuntimeError(
            f"ALB not found: {alb_name}"
        )

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


def main():
    client = create_elbv2_client()

    load_balancer = get_load_balancer(
        client
    )

    load_balancer_arn = load_balancer[
        "LoadBalancerArn"
    ]

    print("=" * 70)
    print("ALB")
    print("=" * 70)

    print(
        "Name:             "
        f"{load_balancer.get('LoadBalancerName')}"
    )

    print(
        "ARN:              "
        f"{load_balancer_arn}"
    )

    print(
        "DNS:              "
        f"{load_balancer.get('DNSName')}"
    )

    print(
        "Scheme:           "
        f"{load_balancer.get('Scheme')}"
    )

    print(
        "Type:             "
        f"{load_balancer.get('Type')}"
    )

    print(
        "State:            "
        f"{load_balancer.get('State', {}).get('Code')}"
    )

    print(
        "VPC:              "
        f"{load_balancer.get('VpcId')}"
    )

    print()

    print("Availability Zones")

    for zone in load_balancer.get(
        "AvailabilityZones",
        [],
    ):
        print(
            f"  {zone.get('ZoneName')}: "
            f"{zone.get('SubnetId')}"
        )

    print()

    print("Security Groups")

    for security_group_id in load_balancer.get(
        "SecurityGroups",
        [],
    ):
        print(
            f"  {security_group_id}"
        )

    print()

    target_groups = get_target_groups(
        client,
        load_balancer_arn,
    )

    print("=" * 70)
    print("TARGET GROUPS")
    print("=" * 70)

    for target_group in target_groups:
        target_group_arn = target_group[
            "TargetGroupArn"
        ]

        print(
            "Name:             "
            f"{target_group.get('TargetGroupName')}"
        )

        print(
            "Protocol:         "
            f"{target_group.get('Protocol')}"
        )

        print(
            "Port:             "
            f"{target_group.get('Port')}"
        )

        print(
            "Target Type:      "
            f"{target_group.get('TargetType')}"
        )

        print(
            "Health Check:     "
            f"{target_group.get('HealthCheckProtocol')} "
            f"{target_group.get('HealthCheckPath')}"
        )

        target_health = get_target_health(
            client,
            target_group_arn,
        )

        print("Targets:")

        for target in target_health:
            target_data = target.get(
                "Target",
                {},
            )

            target_state = target.get(
                "TargetHealth",
                {},
            )

            print(
                f"  {target_data.get('Id')} "
                f"port={target_data.get('Port')} "
                f"state={target_state.get('State')}"
            )

        print()

    listeners = get_listeners(
        client,
        load_balancer_arn,
    )

    print("=" * 70)
    print("LISTENERS")
    print("=" * 70)

    for listener in listeners:
        print(
            f"{listener.get('Protocol')}:"
            f"{listener.get('Port')}"
        )

        for action in listener.get(
            "DefaultActions",
            [],
        ):
            print(
                f"  action={action.get('Type')}"
            )

            target_group_arn = action.get(
                "TargetGroupArn"
            )

            if target_group_arn:
                print(
                    "  target_group="
                    f"{target_group_arn}"
                )

    print()

    tags = get_tags(
        client,
        load_balancer_arn,
    )

    print("=" * 70)
    print("TAGS")
    print("=" * 70)

    for key in sorted(tags):
        print(
            f"{key}={tags[key]}"
        )


if __name__ == "__main__":
    main()