from __future__ import annotations

import json
import sys
from typing import Any

from botocore.exceptions import BotoCoreError, ClientError

from common.aws_clients import get_ec2_client
from common.config import Config


# ============================================================
# Configuration
# ============================================================

PROJECT_NAME = Config.PROJECT_NAME
ENVIRONMENT = Config.ENVIRONMENT
AWS_REGION = Config.AWS_REGION
LOCALSTACK_ENDPOINT = Config.LOCALSTACK_ENDPOINT

PROJECT_PREFIX = f"{PROJECT_NAME}-{ENVIRONMENT}"

EXPECTED_SECURITY_GROUP_NAME = f"{PROJECT_PREFIX}-app-sg"


# ============================================================
# Output Helpers
# ============================================================

def section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}")


def error(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)


def pretty(data: Any) -> None:
    print(
        json.dumps(
            data,
            indent=2,
            ensure_ascii=False,
            default=str,
        )
    )


# ============================================================
# Generic Helpers
# ============================================================

def tags_to_dict(
    tags: list[dict[str, str]] | None,
) -> dict[str, str]:

    if not tags:
        return {}

    return {
        tag["Key"]: tag["Value"]
        for tag in tags
        if "Key" in tag and "Value" in tag
    }


def permission_summary(
    permission: dict[str, Any],
) -> dict[str, Any]:

    return {
        "IpProtocol": permission.get("IpProtocol"),
        "FromPort": permission.get("FromPort"),
        "ToPort": permission.get("ToPort"),

        "Ipv4Ranges": [
            {
                "CidrIp": item.get("CidrIp"),
                "Description": item.get("Description"),
            }
            for item in permission.get(
                "IpRanges",
                [],
            )
        ],

        "Ipv6Ranges": [
            {
                "CidrIpv6": item.get("CidrIpv6"),
                "Description": item.get("Description"),
            }
            for item in permission.get(
                "Ipv6Ranges",
                [],
            )
        ],

        "PrefixListIds": [
            {
                "PrefixListId": item.get("PrefixListId"),
                "Description": item.get("Description"),
            }
            for item in permission.get(
                "PrefixListIds",
                [],
            )
        ],

        "UserIdGroupPairs": [
            {
                "GroupId": item.get("GroupId"),
                "GroupName": item.get("GroupName"),
                "UserId": item.get("UserId"),
                "Description": item.get("Description"),
            }
            for item in permission.get(
                "UserIdGroupPairs",
                [],
            )
        ],
    }


# ============================================================
# Project VPC
# ============================================================

def get_project_vpcs(
    ec2: Any,
) -> list[dict[str, Any]]:

    response = ec2.describe_vpcs(
        Filters=[
            {
                "Name": "tag:Project",
                "Values": [PROJECT_NAME],
            },
            {
                "Name": "tag:Environment",
                "Values": [ENVIRONMENT],
            },
        ]
    )

    return response.get("Vpcs", [])


def show_project_vpc(
    vpc: dict[str, Any],
) -> None:

    section("PROJECT VPC")

    pretty(
        {
            "VpcId": vpc.get("VpcId"),
            "CidrBlock": vpc.get("CidrBlock"),
            "State": vpc.get("State"),
            "IsDefault": vpc.get("IsDefault"),
            "Tags": tags_to_dict(
                vpc.get("Tags")
            ),
        }
    )


# ============================================================
# Application Security Group
# ============================================================

def get_application_security_groups(
    ec2: Any,
    vpc_id: str,
) -> list[dict[str, Any]]:

    response = ec2.describe_security_groups(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            },
            {
                "Name": "group-name",
                "Values": [
                    EXPECTED_SECURITY_GROUP_NAME
                ],
            },
        ]
    )

    return response.get(
        "SecurityGroups",
        [],
    )


def show_security_group_summary(
    security_group: dict[str, Any],
) -> None:

    section("APPLICATION SECURITY GROUP")

    pretty(
        {
            "GroupId": security_group.get("GroupId"),
            "GroupName": security_group.get("GroupName"),
            "Description": security_group.get("Description"),
            "VpcId": security_group.get("VpcId"),
            "OwnerId": security_group.get("OwnerId"),

            "IngressRuleCount": len(
                security_group.get(
                    "IpPermissions",
                    [],
                )
            ),

            "EgressRuleCount": len(
                security_group.get(
                    "IpPermissionsEgress",
                    [],
                )
            ),

            "Tags": tags_to_dict(
                security_group.get("Tags")
            ),
        }
    )


# ============================================================
# Ingress
# ============================================================

def show_ingress_rules(
    security_group: dict[str, Any],
) -> None:

    section(
        "APPLICATION SECURITY GROUP - INGRESS"
    )

    permissions = security_group.get(
        "IpPermissions",
        [],
    )

    if not permissions:
        info(
            "No ingress rules are configured."
        )
        return

    result = [
        permission_summary(permission)
        for permission in permissions
    ]

    pretty(result)


# ============================================================
# Egress
# ============================================================

def show_egress_rules(
    security_group: dict[str, Any],
) -> None:

    section(
        "APPLICATION SECURITY GROUP - EGRESS"
    )

    permissions = security_group.get(
        "IpPermissionsEgress",
        [],
    )

    if not permissions:
        info(
            "No egress rules are configured."
        )
        return

    result = [
        permission_summary(permission)
        for permission in permissions
    ]

    pretty(result)


# ============================================================
# Security Group Rule API
# ============================================================

def show_security_group_rules(
    ec2: Any,
    group_id: str,
) -> None:

    section("SECURITY GROUP RULE RESOURCES")

    try:
        paginator = ec2.get_paginator(
            "describe_security_group_rules"
        )

        rules: list[dict[str, Any]] = []

        for page in paginator.paginate(
            Filters=[
                {
                    "Name": "group-id",
                    "Values": [group_id],
                }
            ]
        ):
            rules.extend(
                page.get(
                    "SecurityGroupRules",
                    [],
                )
            )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "describe_security_group_rules "
            "is unavailable or incomplete "
            f"in LocalStack: {exc}"
        )
        return

    if not rules:
        info(
            "No security group rule "
            "resources returned."
        )
        return

    result = []

    for rule in rules:

        result.append(
            {
                "SecurityGroupRuleId":
                    rule.get(
                        "SecurityGroupRuleId"
                    ),

                "GroupId":
                    rule.get("GroupId"),

                "IsEgress":
                    rule.get("IsEgress"),

                "IpProtocol":
                    rule.get("IpProtocol"),

                "FromPort":
                    rule.get("FromPort"),

                "ToPort":
                    rule.get("ToPort"),

                "CidrIpv4":
                    rule.get("CidrIpv4"),

                "CidrIpv6":
                    rule.get("CidrIpv6"),

                "PrefixListId":
                    rule.get(
                        "PrefixListId"
                    ),

                "ReferencedGroupInfo":
                    rule.get(
                        "ReferencedGroupInfo"
                    ),

                "Description":
                    rule.get("Description"),

                "Tags":
                    tags_to_dict(
                        rule.get("Tags")
                    ),
            }
        )

    pretty(result)


# ============================================================
# Security Group Tags
# ============================================================

def show_security_group_tags(
    security_group: dict[str, Any],
) -> None:

    section("SECURITY GROUP TAGS")

    tags = tags_to_dict(
        security_group.get("Tags")
    )

    if tags:
        pretty(tags)
    else:
        info(
            "No security group tags found."
        )


# ============================================================
# VPC Security Groups
# ============================================================

def get_vpc_security_groups(
    ec2: Any,
    vpc_id: str,
) -> list[dict[str, Any]]:

    response = ec2.describe_security_groups(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            }
        ]
    )

    return response.get(
        "SecurityGroups",
        [],
    )


def show_vpc_security_groups(
    groups: list[dict[str, Any]],
) -> None:

    section(
        "ALL SECURITY GROUPS IN PROJECT VPC"
    )

    result = []

    for group in groups:

        tags = tags_to_dict(
            group.get("Tags")
        )

        result.append(
            {
                "GroupId":
                    group.get("GroupId"),

                "GroupName":
                    group.get("GroupName"),

                "Description":
                    group.get("Description"),

                "IngressRuleCount":
                    len(
                        group.get(
                            "IpPermissions",
                            [],
                        )
                    ),

                "EgressRuleCount":
                    len(
                        group.get(
                            "IpPermissionsEgress",
                            [],
                        )
                    ),

                "NameTag":
                    tags.get("Name"),

                "Component":
                    tags.get("Component"),

                "Service":
                    tags.get("Service"),
            }
        )

    result.sort(
        key=lambda item:
        item.get("GroupName") or ""
    )

    pretty(result)


# ============================================================
# Default Security Group
# ============================================================

def show_default_security_group(
    groups: list[dict[str, Any]],
) -> None:

    section("VPC DEFAULT SECURITY GROUP")

    default_groups = [
        group
        for group in groups
        if group.get("GroupName")
        == "default"
    ]

    if not default_groups:
        warn(
            "VPC default security group "
            "was not found."
        )
        return

    if len(default_groups) > 1:
        warn(
            "Multiple default security "
            "groups were returned."
        )

    group = default_groups[0]

    pretty(
        {
            "GroupId":
                group.get("GroupId"),

            "GroupName":
                group.get("GroupName"),

            "VpcId":
                group.get("VpcId"),

            "IngressRuleCount":
                len(
                    group.get(
                        "IpPermissions",
                        [],
                    )
                ),

            "EgressRuleCount":
                len(
                    group.get(
                        "IpPermissionsEgress",
                        [],
                    )
                ),
        }
    )


# ============================================================
# Project Security Groups
# ============================================================

def show_project_security_groups(
    groups: list[dict[str, Any]],
) -> None:

    section(
        "PROJECT SECURITY GROUP OVERVIEW"
    )

    project_groups = []

    for group in groups:

        tags = tags_to_dict(
            group.get("Tags")
        )

        if tags.get("Project") != PROJECT_NAME:
            continue

        if (
            tags.get("Environment")
            != ENVIRONMENT
        ):
            continue

        project_groups.append(
            {
                "GroupId":
                    group.get("GroupId"),

                "GroupName":
                    group.get("GroupName"),

                "Name":
                    tags.get("Name"),

                "Component":
                    tags.get("Component"),

                "Service":
                    tags.get("Service"),

                "Tier":
                    tags.get("Tier"),

                "Role":
                    tags.get("Role"),
            }
        )

    if project_groups:
        pretty(project_groups)
    else:
        info(
            "No project-managed "
            "security groups found."
        )


# ============================================================
# EC2 Security Group Usage
# ============================================================

def show_ec2_security_group_usage(
    ec2: Any,
    group_id: str,
) -> None:

    section("EC2 SECURITY GROUP USAGE")

    try:
        paginator = ec2.get_paginator(
            "describe_instances"
        )

        instances: list[
            dict[str, Any]
        ] = []

        for page in paginator.paginate(
            Filters=[
                {
                    "Name":
                        "instance.group-id",
                    "Values": [group_id],
                },
                {
                    "Name":
                        "instance-state-name",
                    "Values": [
                        "pending",
                        "running",
                        "stopping",
                        "stopped",
                    ],
                },
            ]
        ):
            for reservation in page.get(
                "Reservations",
                [],
            ):
                instances.extend(
                    reservation.get(
                        "Instances",
                        [],
                    )
                )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "Unable to inspect EC2 "
            f"security group usage: {exc}"
        )
        return

    if not instances:
        info(
            "No EC2 instances currently "
            "use this security group."
        )
        return

    result = []

    for instance in instances:

        tags = tags_to_dict(
            instance.get("Tags")
        )

        result.append(
            {
                "InstanceId":
                    instance.get(
                        "InstanceId"
                    ),

                "Name":
                    tags.get("Name"),

                "State":
                    instance.get(
                        "State",
                        {},
                    ).get("Name"),

                "SubnetId":
                    instance.get(
                        "SubnetId"
                    ),

                "PrivateIpAddress":
                    instance.get(
                        "PrivateIpAddress"
                    ),

                "SecurityGroups":
                    instance.get(
                        "SecurityGroups",
                        [],
                    ),
            }
        )

    pretty(result)


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("SECURITY INSPECTION")

    info(
        f"Project             : "
        f"{PROJECT_NAME}"
    )

    info(
        f"Environment         : "
        f"{ENVIRONMENT}"
    )

    info(
        f"AWS region          : "
        f"{AWS_REGION}"
    )

    info(
        f"LocalStack endpoint : "
        f"{LOCALSTACK_ENDPOINT}"
    )

    info(
        f"Expected App SG     : "
        f"{EXPECTED_SECURITY_GROUP_NAME}"
    )

    try:
        ec2 = get_ec2_client()

        # ----------------------------------------------------
        # Project VPC
        # ----------------------------------------------------

        vpcs = get_project_vpcs(ec2)

        if not vpcs:
            error(
                "No project VPC found."
            )
            return 1

        if len(vpcs) > 1:
            warn(
                "Multiple project VPCs "
                f"found: {len(vpcs)}"
            )

        vpc = vpcs[0]
        vpc_id = vpc.get("VpcId")

        if not vpc_id:
            error(
                "Project VPC has no VpcId."
            )
            return 1

        show_project_vpc(vpc)

        # ----------------------------------------------------
        # Application SG
        # ----------------------------------------------------

        app_groups = (
            get_application_security_groups(
                ec2,
                vpc_id,
            )
        )

        if not app_groups:
            error(
                "Application security "
                "group not found: "
                f"{EXPECTED_SECURITY_GROUP_NAME}"
            )
            return 1

        if len(app_groups) > 1:
            warn(
                "Multiple application "
                "security groups found: "
                f"{len(app_groups)}"
            )

        app_security_group = (
            app_groups[0]
        )

        group_id = (
            app_security_group.get(
                "GroupId"
            )
        )

        if not group_id:
            error(
                "Application security "
                "group has no GroupId."
            )
            return 1

        show_security_group_summary(
            app_security_group
        )

        show_ingress_rules(
            app_security_group
        )

        show_egress_rules(
            app_security_group
        )

        show_security_group_rules(
            ec2,
            group_id,
        )

        show_security_group_tags(
            app_security_group
        )

        # ----------------------------------------------------
        # VPC SG Overview
        # ----------------------------------------------------

        vpc_groups = (
            get_vpc_security_groups(
                ec2,
                vpc_id,
            )
        )

        show_vpc_security_groups(
            vpc_groups
        )

        show_default_security_group(
            vpc_groups
        )

        show_project_security_groups(
            vpc_groups
        )

        # ----------------------------------------------------
        # EC2 Usage
        # ----------------------------------------------------

        show_ec2_security_group_usage(
            ec2,
            group_id,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        error(
            "AWS/LocalStack EC2 API "
            f"error: {exc}"
        )
        return 1

    except Exception as exc:

        error(
            "Unexpected security "
            "inspection error: "
            f"{type(exc).__name__}: "
            f"{exc}"
        )
        return 1

    section(
        "SECURITY INSPECTION COMPLETE"
    )

    print(
        "[SUCCESS] Security inspection "
        "completed."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())