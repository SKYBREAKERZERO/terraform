from __future__ import annotations

import os
import sys
from dataclasses import dataclass
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

EXPECTED_SECURITY_GROUP_NAME = (
    f"{PROJECT_PREFIX}-app-sg"
)

EXPECTED_SECURITY_GROUP_DESCRIPTION = (
    "Security group for private application EC2 instances"
)

EXPECTED_EGRESS_CIDR = os.getenv(
    "EXPECTED_APP_EGRESS_CIDR",
    "0.0.0.0/0",
)

EXPECTED_EGRESS_PROTOCOL = "-1"


# ============================================================
# Expected Tags
# ============================================================

EXPECTED_TAGS = {
    "Name": EXPECTED_SECURITY_GROUP_NAME,
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "ManagedBy": "terraform",
    "Deployment": ENVIRONMENT,
    "Component": "security",
    "Service": "ec2",
    "Tier": "private-app",
    "Role": "application",
}


# ============================================================
# Dangerous Public Ingress
# ============================================================

FORBIDDEN_PUBLIC_PORTS = {
    22: "SSH",
    80: "HTTP",
    443: "HTTPS",
    8080: "Application",
}


# ============================================================
# Result Model
# ============================================================

@dataclass
class ValidationCounters:
    passed: int = 0
    warned: int = 0
    failed: int = 0


COUNTERS = ValidationCounters()


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


def passed(message: str) -> None:
    COUNTERS.passed += 1
    print(f"[PASS] {message}")


def warned(message: str) -> None:
    COUNTERS.warned += 1
    print(f"[WARN] {message}")


def failed(message: str) -> None:
    COUNTERS.failed += 1
    print(f"[FAIL] {message}")


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


def validate_tags(
    actual_tags: dict[str, str],
) -> None:

    section("TAG VALIDATION")

    for key, expected_value in EXPECTED_TAGS.items():

        actual_value = actual_tags.get(key)

        if actual_value == expected_value:
            passed(
                f"{key} tag={expected_value}"
            )
        else:
            failed(
                f"{key} tag={actual_value}, "
                f"expected={expected_value}"
            )


# ============================================================
# Project VPC
# ============================================================

def resolve_project_vpc(
    ec2: Any,
) -> str | None:

    section("PROJECT VPC VALIDATION")

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

    vpcs = response.get(
        "Vpcs",
        [],
    )

    if len(vpcs) != 1:
        failed(
            f"Project VPC count={len(vpcs)}, "
            "expected=1"
        )
        return None

    vpc_id = vpcs[0].get(
        "VpcId"
    )

    if not vpc_id:
        failed(
            "Project VPC does not have "
            "a VpcId"
        )
        return None

    passed(
        f"Exactly one project VPC exists: "
        f"{vpc_id}"
    )

    state = vpcs[0].get(
        "State"
    )

    if state == "available":
        passed(
            "Project VPC state=available"
        )
    else:
        failed(
            f"Project VPC state={state}, "
            "expected=available"
        )

    return vpc_id


# ============================================================
# Application Security Group
# ============================================================

def resolve_application_security_group(
    ec2: Any,
    vpc_id: str,
) -> dict[str, Any] | None:

    section("APPLICATION SECURITY GROUP")

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

    groups = response.get(
        "SecurityGroups",
        [],
    )

    if len(groups) != 1:
        failed(
            "Application security group "
            f"count={len(groups)}, expected=1"
        )
        return None

    security_group = groups[0]

    group_id = security_group.get(
        "GroupId"
    )

    if group_id:
        passed(
            "Application security group "
            f"exists: {group_id}"
        )
    else:
        failed(
            "Application security group "
            "has no GroupId"
        )

    group_name = security_group.get(
        "GroupName"
    )

    if (
        group_name
        == EXPECTED_SECURITY_GROUP_NAME
    ):
        passed(
            "Security group name="
            f"{EXPECTED_SECURITY_GROUP_NAME}"
        )
    else:
        failed(
            "Security group name="
            f"{group_name}, expected="
            f"{EXPECTED_SECURITY_GROUP_NAME}"
        )

    actual_vpc_id = security_group.get(
        "VpcId"
    )

    if actual_vpc_id == vpc_id:
        passed(
            "Security group belongs "
            "to project VPC"
        )
    else:
        failed(
            "Security group VPC="
            f"{actual_vpc_id}, "
            f"expected={vpc_id}"
        )

    description = security_group.get(
        "Description"
    )

    if (
        description
        == EXPECTED_SECURITY_GROUP_DESCRIPTION
    ):
        passed(
            "Security group description "
            "is correct"
        )
    else:
        failed(
            "Security group description="
            f"{description}, expected="
            f"{EXPECTED_SECURITY_GROUP_DESCRIPTION}"
        )

    return security_group


# ============================================================
# Ingress Validation
# ============================================================

def validate_ingress(
    security_group: dict[str, Any],
) -> None:

    section("INGRESS VALIDATION")

    ingress_rules = security_group.get(
        "IpPermissions",
        [],
    )

    if not ingress_rules:
        passed(
            "Application security group "
            "has no ingress rules"
        )
    else:
        failed(
            "Application security group "
            f"ingress rule count="
            f"{len(ingress_rules)}, expected=0"
        )


# ============================================================
# Public CIDR Helper
# ============================================================

def permission_has_public_ipv4(
    permission: dict[str, Any],
) -> bool:

    return any(
        ip_range.get("CidrIp")
        == "0.0.0.0/0"
        for ip_range in permission.get(
            "IpRanges",
            [],
        )
    )


def permission_covers_port(
    permission: dict[str, Any],
    port: int,
) -> bool:

    protocol = permission.get(
        "IpProtocol"
    )

    if protocol == "-1":
        return True

    if protocol not in (
        "tcp",
        "udp",
        "6",
        "17",
    ):
        return False

    from_port = permission.get(
        "FromPort"
    )

    to_port = permission.get(
        "ToPort"
    )

    if (
        from_port is None
        or to_port is None
    ):
        return False

    return from_port <= port <= to_port


# ============================================================
# Dangerous Ingress Guardrails
# ============================================================

def validate_ingress_guardrails(
    security_group: dict[str, Any],
) -> None:

    section("INGRESS SECURITY GUARDRAILS")

    ingress_rules = security_group.get(
        "IpPermissions",
        [],
    )

    for port, label in (
        FORBIDDEN_PUBLIC_PORTS.items()
    ):

        exposed = any(
            permission_has_public_ipv4(
                permission
            )
            and permission_covers_port(
                permission,
                port,
            )
            for permission in ingress_rules
        )

        if exposed:
            failed(
                f"Unrestricted {label} "
                f"ingress detected on "
                f"TCP/{port}"
            )
        else:
            passed(
                f"No unrestricted {label} "
                f"ingress on TCP/{port}"
            )


# ============================================================
# Expected Egress Rule
# ============================================================

def is_expected_egress_rule(
    permission: dict[str, Any],
) -> bool:

    if (
        permission.get("IpProtocol")
        != EXPECTED_EGRESS_PROTOCOL
    ):
        return False

    ipv4_ranges = permission.get(
        "IpRanges",
        [],
    )

    if len(ipv4_ranges) != 1:
        return False

    if (
        ipv4_ranges[0].get("CidrIp")
        != EXPECTED_EGRESS_CIDR
    ):
        return False

    # Expected rule must not contain
    # unexpected destination types.

    if permission.get(
        "Ipv6Ranges",
        [],
    ):
        return False

    if permission.get(
        "PrefixListIds",
        [],
    ):
        return False

    if permission.get(
        "UserIdGroupPairs",
        [],
    ):
        return False

    return True


# ============================================================
# Egress Validation
# ============================================================

def validate_egress(
    security_group: dict[str, Any],
) -> None:

    section("EGRESS VALIDATION")

    egress_rules = security_group.get(
        "IpPermissionsEgress",
        [],
    )

    if len(egress_rules) == 1:
        passed(
            "Application security group "
            "has exactly one egress rule"
        )
    else:
        failed(
            "Application security group "
            f"egress rule count="
            f"{len(egress_rules)}, "
            "expected=1"
        )

    matching_rules = [
        permission
        for permission in egress_rules
        if is_expected_egress_rule(
            permission
        )
    ]

    if len(matching_rules) == 1:
        passed(
            "Expected egress rule exists: "
            f"protocol="
            f"{EXPECTED_EGRESS_PROTOCOL}, "
            f"cidr={EXPECTED_EGRESS_CIDR}"
        )
    else:
        failed(
            "Expected egress rule count="
            f"{len(matching_rules)}, "
            "expected=1"
        )


# ============================================================
# IPv6 Egress Guardrail
# ============================================================

def validate_ipv6_egress(
    security_group: dict[str, Any],
) -> None:

    section("IPV6 EGRESS GUARDRAIL")

    egress_rules = security_group.get(
        "IpPermissionsEgress",
        [],
    )

    public_ipv6_rules = []

    for permission in egress_rules:

        for ipv6_range in permission.get(
            "Ipv6Ranges",
            [],
        ):

            if (
                ipv6_range.get(
                    "CidrIpv6"
                )
                == "::/0"
            ):
                public_ipv6_rules.append(
                    permission
                )

    if not public_ipv6_rules:
        passed(
            "No unrestricted IPv6 "
            "egress to ::/0"
        )
    else:
        failed(
            "Unrestricted IPv6 "
            "egress to ::/0 detected"
        )


# ============================================================
# Default Security Group
# ============================================================

def resolve_default_security_group(
    ec2: Any,
    vpc_id: str,
) -> dict[str, Any] | None:

    section("VPC DEFAULT SECURITY GROUP")

    response = ec2.describe_security_groups(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            },
            {
                "Name": "group-name",
                "Values": ["default"],
            },
        ]
    )

    groups = response.get(
        "SecurityGroups",
        [],
    )

    if len(groups) != 1:
        warned(
            "VPC default security group "
            f"count={len(groups)}, expected=1"
        )
        return None

    group = groups[0]

    group_id = group.get(
        "GroupId"
    )

    if group_id:
        passed(
            "VPC default security group "
            f"exists: {group_id}"
        )
    else:
        warned(
            "VPC default security group "
            "has no GroupId"
        )

    return group


# ============================================================
# SG Separation
# ============================================================

def validate_security_group_separation(
    app_security_group: dict[str, Any],
    default_security_group: dict[str, Any] | None,
) -> None:

    section("SECURITY GROUP SEPARATION")

    if default_security_group is None:
        warned(
            "Unable to validate App SG / "
            "default SG separation"
        )
        return

    app_group_id = app_security_group.get(
        "GroupId"
    )

    default_group_id = (
        default_security_group.get(
            "GroupId"
        )
    )

    if (
        app_group_id
        and default_group_id
        and app_group_id
        != default_group_id
    ):
        passed(
            "Enterprise application SG "
            "is separate from default SG"
        )
    else:
        failed(
            "Application security group "
            "must not be the VPC "
            "default security group"
        )


# ============================================================
# Project Security Group Count
# ============================================================

def validate_project_security_groups(
    ec2: Any,
    vpc_id: str,
) -> None:

    section("PROJECT SECURITY RESOURCE VALIDATION")

    response = ec2.describe_security_groups(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            },
            {
                "Name": "tag:Project",
                "Values": [PROJECT_NAME],
            },
            {
                "Name": "tag:Environment",
                "Values": [ENVIRONMENT],
            },
            {
                "Name": "tag:Component",
                "Values": ["security"],
            },
        ]
    )

    groups = response.get(
        "SecurityGroups",
        [],
    )

    expected_groups = [
        group
        for group in groups
        if (
            group.get("GroupName")
            == EXPECTED_SECURITY_GROUP_NAME
        )
    ]

    if len(expected_groups) == 1:
        passed(
            "Exactly one project "
            "application SG exists"
        )
    else:
        failed(
            "Project application SG "
            f"count={len(expected_groups)}, "
            "expected=1"
        )


# ============================================================
# Security Group Rule API Validation
# ============================================================

def validate_rule_resources(
    ec2: Any,
    group_id: str,
) -> None:

    section("SECURITY GROUP RULE API")

    try:
        paginator = ec2.get_paginator(
            "describe_security_group_rules"
        )

        rules: list[
            dict[str, Any]
        ] = []

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

        warned(
            "describe_security_group_rules "
            "not fully supported by "
            f"LocalStack: {exc}"
        )
        return

    if not rules:
        warned(
            "No standalone security group "
            "rule resources returned"
        )
        return

    ingress_rules = [
        rule
        for rule in rules
        if rule.get("IsEgress")
        is False
    ]

    egress_rules = [
        rule
        for rule in rules
        if rule.get("IsEgress")
        is True
    ]

    if not ingress_rules:
        passed(
            "Rule API reports no "
            "ingress rules"
        )
    else:
        failed(
            "Rule API reports "
            f"{len(ingress_rules)} "
            "ingress rule(s)"
        )

    expected_egress = [
        rule
        for rule in egress_rules
        if (
            rule.get("IpProtocol")
            == EXPECTED_EGRESS_PROTOCOL
            and rule.get("CidrIpv4")
            == EXPECTED_EGRESS_CIDR
        )
    ]

    if len(expected_egress) == 1:
        passed(
            "Rule API reports expected "
            "application egress rule"
        )
    else:
        warned(
            "Rule API expected egress "
            f"count={len(expected_egress)}. "
            "Primary IpPermissionsEgress "
            "validation remains authoritative."
        )


# ============================================================
# EC2 Usage Inspection
# ============================================================

def validate_ec2_usage(
    ec2: Any,
    group_id: str,
) -> None:

    section("EC2 SECURITY GROUP USAGE")

    try:
        paginator = ec2.get_paginator(
            "describe_instances"
        )

        instance_ids: list[str] = []

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
                for instance in (
                    reservation.get(
                        "Instances",
                        [],
                    )
                ):
                    instance_id = (
                        instance.get(
                            "InstanceId"
                        )
                    )

                    if instance_id:
                        instance_ids.append(
                            instance_id
                        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warned(
            "Unable to inspect EC2 "
            f"SG usage: {exc}"
        )
        return

    if instance_ids:
        info(
            "Application SG currently "
            "attached to EC2: "
            + ", ".join(instance_ids)
        )
    else:
        info(
            "Application SG is currently "
            "not attached to EC2. This is "
            "acceptable when LocalStack "
            "default-SG compatibility mode "
            "is enabled."
        )


# ============================================================
# Summary
# ============================================================

def print_summary() -> int:

    section("VALIDATION SUMMARY")

    print(
        f"PASS : {COUNTERS.passed}"
    )

    print(
        f"WARN : {COUNTERS.warned}"
    )

    print(
        f"FAIL : {COUNTERS.failed}"
    )

    print()

    if COUNTERS.failed == 0:
        print(
            "[SUCCESS] Security "
            "validation passed."
        )
        return 0

    print(
        "[FAILED] Security "
        "validation failed."
    )

    return 1


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("SECURITY VALIDATION")

    info(
        f"Project: {PROJECT_NAME}"
    )

    info(
        f"Environment: {ENVIRONMENT}"
    )

    info(
        f"AWS Region: {AWS_REGION}"
    )

    info(
        "LocalStack endpoint: "
        f"{LOCALSTACK_ENDPOINT}"
    )

    info(
        "Expected application SG: "
        f"{EXPECTED_SECURITY_GROUP_NAME}"
    )

    info(
        "Expected egress: "
        f"{EXPECTED_EGRESS_PROTOCOL} "
        f"-> {EXPECTED_EGRESS_CIDR}"
    )

    try:
        ec2 = get_ec2_client()

        # ----------------------------------------------------
        # VPC
        # ----------------------------------------------------

        vpc_id = resolve_project_vpc(
            ec2
        )

        if not vpc_id:
            return print_summary()

        # ----------------------------------------------------
        # Application Security Group
        # ----------------------------------------------------

        security_group = (
            resolve_application_security_group(
                ec2,
                vpc_id,
            )
        )

        if security_group is None:
            return print_summary()

        group_id = security_group.get(
            "GroupId"
        )

        # ----------------------------------------------------
        # Rules
        # ----------------------------------------------------

        validate_ingress(
            security_group
        )

        validate_ingress_guardrails(
            security_group
        )

        validate_egress(
            security_group
        )

        validate_ipv6_egress(
            security_group
        )

        # ----------------------------------------------------
        # Tags
        # ----------------------------------------------------

        validate_tags(
            tags_to_dict(
                security_group.get(
                    "Tags"
                )
            )
        )

        # ----------------------------------------------------
        # Default SG
        # ----------------------------------------------------

        default_security_group = (
            resolve_default_security_group(
                ec2,
                vpc_id,
            )
        )

        validate_security_group_separation(
            security_group,
            default_security_group,
        )

        # ----------------------------------------------------
        # Project Resources
        # ----------------------------------------------------

        validate_project_security_groups(
            ec2,
            vpc_id,
        )

        # ----------------------------------------------------
        # Standalone Rule API
        # ----------------------------------------------------

        if group_id:
            validate_rule_resources(
                ec2,
                group_id,
            )

            validate_ec2_usage(
                ec2,
                group_id,
            )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            "AWS/LocalStack EC2 API "
            f"error: {exc}"
        )

    except Exception as exc:

        failed(
            "Unexpected security "
            "validation error: "
            f"{type(exc).__name__}: "
            f"{exc}"
        )

    return print_summary()


if __name__ == "__main__":
    sys.exit(main())