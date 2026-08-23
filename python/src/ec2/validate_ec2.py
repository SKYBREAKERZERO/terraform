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

EXPECTED_INSTANCE_COUNT = 2

EXPECTED_AMI_ID = os.getenv(
    "EXPECTED_AMI_ID",
    "ami-df5de72bdb3b",
)

EXPECTED_INSTANCE_TYPE = os.getenv(
    "EXPECTED_INSTANCE_TYPE",
    "t3.micro",
)

EXPECTED_ROOT_VOLUME_TYPE = os.getenv(
    "EXPECTED_ROOT_VOLUME_TYPE",
    "gp3",
)

EXPECTED_ROOT_VOLUME_SIZE = int(
    os.getenv(
        "EXPECTED_ROOT_VOLUME_SIZE",
        "20",
    )
)

EXPECTED_METADATA_HTTP_ENDPOINT = "enabled"
EXPECTED_METADATA_HTTP_TOKENS = "required"

EXPECTED_METADATA_HOP_LIMIT = int(
    os.getenv(
        "EXPECTED_METADATA_HOP_LIMIT",
        "1",
    )
)

EXPECTED_COMPONENT = "compute"
EXPECTED_SERVICE = "ec2"
EXPECTED_TIER = "private-app"
EXPECTED_ROLE = "application"

EXPECTED_MANAGED_BY = "terraform"
EXPECTED_DEPLOYMENT = ENVIRONMENT

EXPECTED_IAM_INSTANCE_PROFILE_NAME = (
    f"{PROJECT_NAME}-{ENVIRONMENT}-ec2-instance-profile"
)

EXPECTED_APP_SECURITY_GROUP_NAME = (
    f"{PROJECT_NAME}-{ENVIRONMENT}-app-sg"
)

LOCALSTACK_USE_DEFAULT_SECURITY_GROUP = (
    os.getenv(
        "LOCALSTACK_USE_DEFAULT_SECURITY_GROUP",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected Placement
# ============================================================

EXPECTED_INSTANCES = {
    "app-a": {
        "name": f"{PROJECT_NAME}-{ENVIRONMENT}-app-a-ec2",
        "subnet_name": f"{PROJECT_NAME}-{ENVIRONMENT}-app-a",
        "availability_zone": f"{AWS_REGION}a",
    },
    "app-c": {
        "name": f"{PROJECT_NAME}-{ENVIRONMENT}-app-c-ec2",
        "subnet_name": f"{PROJECT_NAME}-{ENVIRONMENT}-app-c",
        "availability_zone": f"{AWS_REGION}c",
    },
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


def nested_get(
    data: dict[str, Any],
    *keys: str,
    default: Any = None,
) -> Any:

    current: Any = data

    for key in keys:
        if not isinstance(current, dict):
            return default

        current = current.get(key)

        if current is None:
            return default

    return current


def check_equal(
    actual: Any,
    expected: Any,
    description: str,
) -> None:

    if actual == expected:
        passed(
            f"{description}={expected}"
        )
    else:
        failed(
            f"{description}={actual}, "
            f"expected={expected}"
        )


def check_tag(
    tags: dict[str, str],
    key: str,
    expected: str,
    prefix: str,
) -> None:

    actual = tags.get(key)

    if actual == expected:
        passed(
            f"{prefix} {key} tag={expected}"
        )
    else:
        failed(
            f"{prefix} {key} tag={actual}, "
            f"expected={expected}"
        )


# ============================================================
# EC2 Discovery
# ============================================================

def discover_application_instances(
    ec2: Any,
) -> list[dict[str, Any]]:

    filters = [
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
            "Values": [EXPECTED_COMPONENT],
        },
        {
            "Name": "tag:Role",
            "Values": [EXPECTED_ROLE],
        },
        {
            "Name": "instance-state-name",
            "Values": [
                "pending",
                "running",
                "stopping",
                "stopped",
            ],
        },
    ]

    instances: list[dict[str, Any]] = []

    paginator = ec2.get_paginator(
        "describe_instances"
    )

    for page in paginator.paginate(
        Filters=filters
    ):
        for reservation in page.get(
            "Reservations",
            [],
        ):
            instances.extend(
                reservation.get(
                    "Instances",
                    []
                )
            )

    return instances


def index_instances_by_subnet_role(
    instances: list[dict[str, Any]],
) -> dict[str, list[dict[str, Any]]]:

    result: dict[
        str,
        list[dict[str, Any]],
    ] = {}

    for instance in instances:
        tags = tags_to_dict(
            instance.get("Tags")
        )

        subnet_role = tags.get(
            "SubnetRole"
        )

        if not subnet_role:
            continue

        result.setdefault(
            subnet_role,
            [],
        ).append(instance)

    return result


# ============================================================
# VPC
# ============================================================

def resolve_project_vpc(
    ec2: Any,
) -> str | None:

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

    if len(vpcs) == 1:
        vpc_id = vpcs[0].get(
            "VpcId"
        )

        passed(
            f"Exactly one project VPC found: "
            f"{vpc_id}"
        )

        return vpc_id

    failed(
        "Project VPC count="
        f"{len(vpcs)}, expected=1"
    )

    return None


# ============================================================
# Subnets
# ============================================================

def resolve_expected_subnets(
    ec2: Any,
    vpc_id: str,
) -> dict[str, str]:

    result: dict[str, str] = {}

    for subnet_role, expected in (
        EXPECTED_INSTANCES.items()
    ):

        response = ec2.describe_subnets(
            Filters=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                },
                {
                    "Name": "tag:Name",
                    "Values": [
                        expected[
                            "subnet_name"
                        ]
                    ],
                },
                {
                    "Name": "tag:Tier",
                    "Values": [
                        "private-app"
                    ],
                },
            ]
        )

        subnets = response.get(
            "Subnets",
            [],
        )

        if len(subnets) == 1:
            subnet_id = subnets[0].get(
                "SubnetId"
            )

            if subnet_id:
                result[
                    subnet_role
                ] = subnet_id

                passed(
                    f"{subnet_role} expected "
                    f"subnet resolved: "
                    f"{subnet_id}"
                )
        else:
            failed(
                f"{subnet_role} subnet "
                f"count={len(subnets)}, "
                "expected=1"
            )

    return result


# ============================================================
# Security Groups
# ============================================================

def resolve_app_security_group(
    ec2: Any,
    vpc_id: str,
) -> str | None:

    response = (
        ec2.describe_security_groups(
            Filters=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                },
                {
                    "Name": "group-name",
                    "Values": [
                        EXPECTED_APP_SECURITY_GROUP_NAME
                    ],
                },
            ]
        )
    )

    groups = response.get(
        "SecurityGroups",
        [],
    )

    if len(groups) != 1:
        failed(
            "Enterprise application SG "
            f"count={len(groups)}, "
            "expected=1"
        )
        return None

    group_id = groups[0].get(
        "GroupId"
    )

    passed(
        "Enterprise application SG exists: "
        f"{group_id}"
    )

    return group_id


def resolve_default_security_group(
    ec2: Any,
    vpc_id: str,
) -> str | None:

    response = (
        ec2.describe_security_groups(
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
    )

    groups = response.get(
        "SecurityGroups",
        [],
    )

    if len(groups) != 1:
        failed(
            "VPC default SG "
            f"count={len(groups)}, "
            "expected=1"
        )
        return None

    return groups[0].get(
        "GroupId"
    )


# ============================================================
# Instance Validation
# ============================================================

def validate_instance_identity(
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"INSTANCE IDENTITY - {subnet_role}"
    )

    instance_id = instance.get(
        "InstanceId"
    )

    tags = tags_to_dict(
        instance.get("Tags")
    )

    expected = EXPECTED_INSTANCES[
        subnet_role
    ]

    info(
        f"Instance ID: {instance_id}"
    )

    check_equal(
        tags.get("Name"),
        expected["name"],
        f"{subnet_role} Name",
    )

    check_equal(
        nested_get(
            instance,
            "State",
            "Name",
        ),
        "running",
        f"{subnet_role} state",
    )

    check_equal(
        instance.get("ImageId"),
        EXPECTED_AMI_ID,
        f"{subnet_role} AMI",
    )

    check_equal(
        instance.get("InstanceType"),
        EXPECTED_INSTANCE_TYPE,
        f"{subnet_role} instance type",
    )


# ============================================================
# Network Validation
# ============================================================

def validate_network(
    instance: dict[str, Any],
    subnet_role: str,
    vpc_id: str,
    subnet_ids: dict[str, str],
) -> None:

    section(
        f"NETWORK VALIDATION - {subnet_role}"
    )

    check_equal(
        instance.get("VpcId"),
        vpc_id,
        f"{subnet_role} VPC",
    )

    expected_subnet_id = (
        subnet_ids.get(
            subnet_role
        )
    )

    if expected_subnet_id:
        check_equal(
            instance.get("SubnetId"),
            expected_subnet_id,
            f"{subnet_role} subnet",
        )

    expected_az = (
        EXPECTED_INSTANCES[
            subnet_role
        ]["availability_zone"]
    )

    check_equal(
        nested_get(
            instance,
            "Placement",
            "AvailabilityZone",
        ),
        expected_az,
        f"{subnet_role} AZ",
    )

    private_ip = instance.get(
        "PrivateIpAddress"
    )

    if private_ip:
        passed(
            f"{subnet_role} private IP="
            f"{private_ip}"
        )
    else:
        failed(
            f"{subnet_role} has no private IP"
        )

    public_ip = instance.get(
        "PublicIpAddress"
    )

    if not public_ip:
        passed(
            f"{subnet_role} has no public IP"
        )
    else:
        failed(
            f"{subnet_role} public IP="
            f"{public_ip}, expected=None"
        )

    source_dest_check = (
        instance.get(
            "SourceDestCheck"
        )
    )

    check_equal(
        source_dest_check,
        True,
        f"{subnet_role} SourceDestCheck",
    )


# ============================================================
# Security Group Validation
# ============================================================

def validate_security_groups(
    instance: dict[str, Any],
    subnet_role: str,
    app_security_group_id: str | None,
    default_security_group_id: str | None,
) -> None:

    section(
        f"SECURITY GROUP VALIDATION - "
        f"{subnet_role}"
    )

    groups = instance.get(
        "SecurityGroups",
        [],
    )

    attached_ids = {
        group.get("GroupId")
        for group in groups
        if group.get("GroupId")
    }

    if attached_ids:
        passed(
            f"{subnet_role} has "
            f"{len(attached_ids)} SG attachment(s)"
        )
    else:
        failed(
            f"{subnet_role} has no SG attachment"
        )
        return

    if (
        LOCALSTACK_USE_DEFAULT_SECURITY_GROUP
    ):
        expected_group_id = (
            default_security_group_id
        )

        mode = "LocalStack default SG"
    else:
        expected_group_id = (
            app_security_group_id
        )

        mode = "enterprise application SG"

    if not expected_group_id:
        failed(
            f"{subnet_role} unable to resolve "
            f"expected {mode}"
        )
        return

    if expected_group_id in attached_ids:
        passed(
            f"{subnet_role} uses "
            f"{mode}={expected_group_id}"
        )
    else:
        failed(
            f"{subnet_role} attached SGs="
            f"{sorted(attached_ids)}, "
            f"expected {expected_group_id}"
        )

    if len(attached_ids) == 1:
        passed(
            f"{subnet_role} has exactly "
            "one security group"
        )
    else:
        failed(
            f"{subnet_role} SG count="
            f"{len(attached_ids)}, expected=1"
        )


# ============================================================
# IAM Instance Profile Validation
# ============================================================

def validate_iam_profile(
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"IAM VALIDATION - {subnet_role}"
    )

    profile = instance.get(
        "IamInstanceProfile"
    )

    if not profile:
        failed(
            f"{subnet_role} IAM "
            "instance profile missing"
        )
        return

    arn = profile.get("Arn")

    if not arn:
        failed(
            f"{subnet_role} IAM profile "
            "ARN missing"
        )
        return

    passed(
        f"{subnet_role} IAM instance "
        "profile attached"
    )

    if arn.endswith(
        f"/{EXPECTED_IAM_INSTANCE_PROFILE_NAME}"
    ):
        passed(
            f"{subnet_role} IAM profile="
            f"{EXPECTED_IAM_INSTANCE_PROFILE_NAME}"
        )
    else:
        failed(
            f"{subnet_role} IAM profile "
            f"ARN={arn}, expected="
            f"{EXPECTED_IAM_INSTANCE_PROFILE_NAME}"
        )


# ============================================================
# IMDS Validation
# ============================================================

def validate_metadata_options(
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"IMDS VALIDATION - {subnet_role}"
    )

    metadata = instance.get(
        "MetadataOptions",
        {},
    )

    check_equal(
        metadata.get("HttpEndpoint"),
        EXPECTED_METADATA_HTTP_ENDPOINT,
        f"{subnet_role} IMDS endpoint",
    )

    check_equal(
        metadata.get("HttpTokens"),
        EXPECTED_METADATA_HTTP_TOKENS,
        f"{subnet_role} IMDS tokens",
    )

    check_equal(
        metadata.get(
            "HttpPutResponseHopLimit"
        ),
        EXPECTED_METADATA_HOP_LIMIT,
        f"{subnet_role} IMDS hop limit",
    )

    metadata_tags = metadata.get(
        "InstanceMetadataTags"
    )

    if metadata_tags is None:
        warned(
            f"{subnet_role} "
            "InstanceMetadataTags not returned "
            "by EC2 API"
        )
    elif metadata_tags == "enabled":
        passed(
            f"{subnet_role} "
            "instance metadata tags=enabled"
        )
    else:
        failed(
            f"{subnet_role} "
            "instance metadata tags="
            f"{metadata_tags}, expected=enabled"
        )


# ============================================================
# Monitoring Validation
# ============================================================

def validate_monitoring(
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"MONITORING VALIDATION - "
        f"{subnet_role}"
    )

    monitoring_state = nested_get(
        instance,
        "Monitoring",
        "State",
    )

    if monitoring_state == "disabled":
        passed(
            f"{subnet_role} detailed "
            "monitoring=disabled"
        )
    else:
        failed(
            f"{subnet_role} monitoring="
            f"{monitoring_state}, "
            "expected=disabled"
        )

    check_equal(
        instance.get("EbsOptimized"),
        False,
        f"{subnet_role} EbsOptimized",
    )


# ============================================================
# Root EBS Validation
# ============================================================

def validate_root_volume(
    ec2: Any,
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"EBS VALIDATION - {subnet_role}"
    )

    root_device_name = instance.get(
        "RootDeviceName"
    )

    mappings = instance.get(
        "BlockDeviceMappings",
        [],
    )

    root_mapping: dict[str, Any] | None = None

    for mapping in mappings:
        if (
            mapping.get("DeviceName")
            == root_device_name
        ):
            root_mapping = mapping
            break

    if not root_mapping:
        failed(
            f"{subnet_role} root block "
            "device mapping missing"
        )
        return

    ebs_mapping = root_mapping.get(
        "Ebs",
        {},
    )

    volume_id = ebs_mapping.get(
        "VolumeId"
    )

    if not volume_id:
        failed(
            f"{subnet_role} root "
            "volume ID missing"
        )
        return

    passed(
        f"{subnet_role} root volume="
        f"{volume_id}"
    )

    delete_on_termination = (
        ebs_mapping.get(
            "DeleteOnTermination"
        )
    )

    if delete_on_termination is None:
        warned(
            f"{subnet_role} "
            "DeleteOnTermination not "
            "returned by LocalStack"
        )
    else:
        check_equal(
            delete_on_termination,
            True,
            f"{subnet_role} "
            "DeleteOnTermination",
        )

    response = ec2.describe_volumes(
        VolumeIds=[volume_id]
    )

    volumes = response.get(
        "Volumes",
        [],
    )

    if len(volumes) != 1:
        failed(
            f"{subnet_role} root volume "
            f"lookup count={len(volumes)}, "
            "expected=1"
        )
        return

    volume = volumes[0]

    check_equal(
        volume.get("VolumeType"),
        EXPECTED_ROOT_VOLUME_TYPE,
        f"{subnet_role} root volume type",
    )

    check_equal(
        volume.get("Size"),
        EXPECTED_ROOT_VOLUME_SIZE,
        f"{subnet_role} root volume size GiB",
    )

    check_equal(
        volume.get("Encrypted"),
        True,
        f"{subnet_role} root volume encrypted",
    )

    instance_az = nested_get(
        instance,
        "Placement",
        "AvailabilityZone",
    )

    volume_az = volume.get(
        "AvailabilityZone"
    )

    if volume_az is None:
        warned(
            f"{subnet_role} EBS AZ "
            "not returned"
        )
    else:
        check_equal(
            volume_az,
            instance_az,
            f"{subnet_role} root volume AZ",
        )


# ============================================================
# Tag Validation
# ============================================================

def validate_tags(
    instance: dict[str, Any],
    subnet_role: str,
) -> None:

    section(
        f"TAG VALIDATION - {subnet_role}"
    )

    tags = tags_to_dict(
        instance.get("Tags")
    )

    check_tag(
        tags,
        "Project",
        PROJECT_NAME,
        subnet_role,
    )

    check_tag(
        tags,
        "Environment",
        ENVIRONMENT,
        subnet_role,
    )

    check_tag(
        tags,
        "ManagedBy",
        EXPECTED_MANAGED_BY,
        subnet_role,
    )

    check_tag(
        tags,
        "Deployment",
        EXPECTED_DEPLOYMENT,
        subnet_role,
    )

    check_tag(
        tags,
        "Component",
        EXPECTED_COMPONENT,
        subnet_role,
    )

    check_tag(
        tags,
        "Service",
        EXPECTED_SERVICE,
        subnet_role,
    )

    check_tag(
        tags,
        "Tier",
        EXPECTED_TIER,
        subnet_role,
    )

    check_tag(
        tags,
        "Role",
        EXPECTED_ROLE,
        subnet_role,
    )

    check_tag(
        tags,
        "SubnetRole",
        subnet_role,
        subnet_role,
    )


# ============================================================
# Multi-AZ Validation
# ============================================================

def validate_multi_az(
    instances: list[dict[str, Any]],
) -> None:

    section("MULTI-AZ VALIDATION")

    availability_zones = {
        nested_get(
            instance,
            "Placement",
            "AvailabilityZone",
        )
        for instance in instances
    }

    availability_zones.discard(
        None
    )

    if len(availability_zones) == 2:
        passed(
            "Application instances span "
            "two Availability Zones: "
            f"{sorted(availability_zones)}"
        )
    else:
        failed(
            "Application instances span "
            f"{len(availability_zones)} AZ(s), "
            "expected=2"
        )


# ============================================================
# Public IP Global Guardrail
# ============================================================

def validate_public_ip_guardrail(
    instances: list[dict[str, Any]],
) -> None:

    section("PUBLIC IP GUARDRAIL")

    offenders = [
        instance.get("InstanceId")
        for instance in instances
        if instance.get(
            "PublicIpAddress"
        )
    ]

    if not offenders:
        passed(
            "No application EC2 instance "
            "has a public IP"
        )
    else:
        failed(
            "Public IP detected on: "
            + ", ".join(
                str(item)
                for item in offenders
            )
        )


# ============================================================
# Subnet Role Uniqueness
# ============================================================

def validate_subnet_roles(
    indexed_instances: dict[
        str,
        list[dict[str, Any]],
    ],
) -> None:

    section("INSTANCE ROLE VALIDATION")

    expected_roles = set(
        EXPECTED_INSTANCES.keys()
    )

    actual_roles = set(
        indexed_instances.keys()
    )

    for subnet_role in sorted(
        expected_roles
    ):
        count = len(
            indexed_instances.get(
                subnet_role,
                [],
            )
        )

        if count == 1:
            instance_id = (
                indexed_instances[
                    subnet_role
                ][0].get(
                    "InstanceId"
                )
            )

            passed(
                f"{subnet_role} instance "
                f"exists: {instance_id}"
            )
        else:
            failed(
                f"{subnet_role} instance "
                f"count={count}, expected=1"
            )

    unexpected = (
        actual_roles - expected_roles
    )

    if unexpected:
        failed(
            "Unexpected SubnetRole values: "
            f"{sorted(unexpected)}"
        )
    else:
        passed(
            "No unexpected SubnetRole "
            "values detected"
        )


# ============================================================
# Instance Status
# ============================================================

def validate_instance_status(
    ec2: Any,
    instances: list[dict[str, Any]],
) -> None:

    section("EC2 STATUS CHECK")

    instance_ids = [
        instance["InstanceId"]
        for instance in instances
        if instance.get("InstanceId")
    ]

    if not instance_ids:
        return

    try:
        response = (
            ec2.describe_instance_status(
                InstanceIds=instance_ids,
                IncludeAllInstances=True,
            )
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:
        warned(
            "EC2 instance status API "
            "not available or incomplete "
            f"in LocalStack: {exc}"
        )
        return

    statuses = response.get(
        "InstanceStatuses",
        [],
    )

    if not statuses:
        warned(
            "EC2 status checks were not "
            "returned by LocalStack"
        )
        return

    for status in statuses:
        instance_id = status.get(
            "InstanceId"
        )

        instance_state = nested_get(
            status,
            "InstanceState",
            "Name",
        )

        if instance_state == "running":
            passed(
                f"{instance_id} status "
                "state=running"
            )
        else:
            failed(
                f"{instance_id} status "
                f"state={instance_state}, "
                "expected=running"
            )

        system_status = nested_get(
            status,
            "SystemStatus",
            "Status",
        )

        instance_status = nested_get(
            status,
            "InstanceStatus",
            "Status",
        )

        if system_status in (
            None,
            "not-applicable",
        ):
            warned(
                f"{instance_id} system "
                "status not fully emulated"
            )
        elif system_status == "ok":
            passed(
                f"{instance_id} "
                "system status=ok"
            )
        else:
            warned(
                f"{instance_id} "
                "system status="
                f"{system_status}"
            )

        if instance_status in (
            None,
            "not-applicable",
        ):
            warned(
                f"{instance_id} instance "
                "status not fully emulated"
            )
        elif instance_status == "ok":
            passed(
                f"{instance_id} "
                "instance status=ok"
            )
        else:
            warned(
                f"{instance_id} "
                "instance status="
                f"{instance_status}"
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
            "[SUCCESS] EC2 validation passed."
        )
        return 0

    print(
        "[FAILED] EC2 validation failed."
    )

    return 1


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("EC2 VALIDATION")

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
        f"Expected AMI: "
        f"{EXPECTED_AMI_ID}"
    )

    info(
        "Expected instance type: "
        f"{EXPECTED_INSTANCE_TYPE}"
    )

    info(
        "LocalStack default SG mode: "
        f"{LOCALSTACK_USE_DEFAULT_SECURITY_GROUP}"
    )

    try:
        ec2 = get_ec2_client()

        section("VPC VALIDATION")

        vpc_id = resolve_project_vpc(
            ec2
        )

        if not vpc_id:
            return print_summary()

        section("SUBNET VALIDATION")

        expected_subnet_ids = (
            resolve_expected_subnets(
                ec2,
                vpc_id,
            )
        )

        section("SECURITY RESOURCE VALIDATION")

        app_security_group_id = (
            resolve_app_security_group(
                ec2,
                vpc_id,
            )
        )

        default_security_group_id = (
            resolve_default_security_group(
                ec2,
                vpc_id,
            )
        )

        if default_security_group_id:
            passed(
                "VPC default SG exists: "
                f"{default_security_group_id}"
            )

        section("EC2 DISCOVERY")

        instances = (
            discover_application_instances(
                ec2
            )
        )

        if (
            len(instances)
            == EXPECTED_INSTANCE_COUNT
        ):
            passed(
                "Application EC2 instance "
                f"count={EXPECTED_INSTANCE_COUNT}"
            )
        else:
            failed(
                "Application EC2 instance "
                f"count={len(instances)}, "
                f"expected="
                f"{EXPECTED_INSTANCE_COUNT}"
            )

        if not instances:
            return print_summary()

        info(
            "Instances: "
            + ", ".join(
                instance.get(
                    "InstanceId",
                    "<unknown>",
                )
                for instance in instances
            )
        )

        indexed_instances = (
            index_instances_by_subnet_role(
                instances
            )
        )

        validate_subnet_roles(
            indexed_instances
        )

        for subnet_role in (
            EXPECTED_INSTANCES
        ):

            matching_instances = (
                indexed_instances.get(
                    subnet_role,
                    [],
                )
            )

            if len(
                matching_instances
            ) != 1:
                continue

            instance = (
                matching_instances[0]
            )

            validate_instance_identity(
                instance,
                subnet_role,
            )

            validate_network(
                instance,
                subnet_role,
                vpc_id,
                expected_subnet_ids,
            )

            validate_security_groups(
                instance,
                subnet_role,
                app_security_group_id,
                default_security_group_id,
            )

            validate_iam_profile(
                instance,
                subnet_role,
            )

            validate_metadata_options(
                instance,
                subnet_role,
            )

            validate_monitoring(
                instance,
                subnet_role,
            )

            validate_root_volume(
                ec2,
                instance,
                subnet_role,
            )

            validate_tags(
                instance,
                subnet_role,
            )

        validate_multi_az(
            instances
        )

        validate_public_ip_guardrail(
            instances
        )

        validate_instance_status(
            ec2,
            instances,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            "AWS/LocalStack API error: "
            f"{exc}"
        )

    except Exception as exc:

        failed(
            "Unexpected validation error: "
            f"{type(exc).__name__}: "
            f"{exc}"
        )

    return print_summary()


if __name__ == "__main__":
    sys.exit(main())