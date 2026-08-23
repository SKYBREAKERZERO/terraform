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

EXPECTED_COMPONENT = "compute"
EXPECTED_ROLE = "application"


# ============================================================
# Helpers
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
            default=str,
            ensure_ascii=False,
        )
    )


def tags_to_dict(tags: list[dict[str, str]] | None) -> dict[str, str]:
    if not tags:
        return {}

    return {
        tag["Key"]: tag["Value"]
        for tag in tags
        if "Key" in tag and "Value" in tag
    }


def get_nested(
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

    try:
        paginator = ec2.get_paginator("describe_instances")

        for page in paginator.paginate(Filters=filters):
            for reservation in page.get("Reservations", []):
                instances.extend(
                    reservation.get("Instances", [])
                )

    except (ClientError, BotoCoreError) as exc:
        error(f"Unable to discover EC2 instances: {exc}")
        raise

    return instances


# ============================================================
# Instance Summary
# ============================================================

def show_instance_summary(
    instances: list[dict[str, Any]],
) -> None:

    section("EC2 INSTANCE SUMMARY")

    summary = []

    for instance in instances:
        tags = tags_to_dict(instance.get("Tags"))

        summary.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "Name": tags.get("Name"),
                "SubnetRole": tags.get("SubnetRole"),
                "InstanceType": instance.get("InstanceType"),
                "State": get_nested(
                    instance,
                    "State",
                    "Name",
                ),
                "ImageId": instance.get("ImageId"),
                "AvailabilityZone": get_nested(
                    instance,
                    "Placement",
                    "AvailabilityZone",
                ),
                "VpcId": instance.get("VpcId"),
                "SubnetId": instance.get("SubnetId"),
                "PrivateIpAddress": instance.get(
                    "PrivateIpAddress"
                ),
                "PublicIpAddress": instance.get(
                    "PublicIpAddress"
                ),
            }
        )

    pretty(summary)


# ============================================================
# AMI / Platform
# ============================================================

def show_platform(
    instances: list[dict[str, Any]],
) -> None:

    section("AMI / PLATFORM")

    result = []

    for instance in instances:
        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "ImageId": instance.get("ImageId"),
                "Architecture": instance.get("Architecture"),
                "Platform": instance.get("Platform"),
                "PlatformDetails": instance.get(
                    "PlatformDetails"
                ),
                "VirtualizationType": instance.get(
                    "VirtualizationType"
                ),
                "RootDeviceType": instance.get(
                    "RootDeviceType"
                ),
                "RootDeviceName": instance.get(
                    "RootDeviceName"
                ),
            }
        )

    pretty(result)


# ============================================================
# Network
# ============================================================

def show_network(
    instances: list[dict[str, Any]],
) -> None:

    section("NETWORK")

    result = []

    for instance in instances:
        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "VpcId": instance.get("VpcId"),
                "SubnetId": instance.get("SubnetId"),
                "AvailabilityZone": get_nested(
                    instance,
                    "Placement",
                    "AvailabilityZone",
                ),
                "PrivateIpAddress": instance.get(
                    "PrivateIpAddress"
                ),
                "PrivateDnsName": instance.get(
                    "PrivateDnsName"
                ),
                "PublicIpAddress": instance.get(
                    "PublicIpAddress"
                ),
                "PublicDnsName": instance.get(
                    "PublicDnsName"
                ),
                "SourceDestCheck": instance.get(
                    "SourceDestCheck"
                ),
            }
        )

    pretty(result)


# ============================================================
# Security Groups
# ============================================================

def show_security_groups(
    ec2: Any,
    instances: list[dict[str, Any]],
) -> None:

    section("SECURITY GROUP ATTACHMENTS")

    group_ids: set[str] = set()

    for instance in instances:
        groups = instance.get("SecurityGroups", [])

        print()
        info(f"Instance: {instance.get('InstanceId')}")

        pretty(groups)

        for group in groups:
            group_id = group.get("GroupId")

            if group_id:
                group_ids.add(group_id)

    if not group_ids:
        warn("No security groups found.")
        return

    section("SECURITY GROUP DETAILS")

    try:
        response = ec2.describe_security_groups(
            GroupIds=sorted(group_ids)
        )

        pretty(response.get("SecurityGroups", []))

    except (ClientError, BotoCoreError) as exc:
        warn(
            "Unable to retrieve security group details: "
            f"{exc}"
        )


# ============================================================
# IAM Instance Profile
# ============================================================

def show_iam_instance_profiles(
    instances: list[dict[str, Any]],
) -> None:

    section("IAM INSTANCE PROFILE")

    result = []

    for instance in instances:
        profile = instance.get("IamInstanceProfile")

        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "IamInstanceProfile": profile,
            }
        )

    pretty(result)


# ============================================================
# Metadata / IMDS
# ============================================================

def show_metadata_options(
    instances: list[dict[str, Any]],
) -> None:

    section("INSTANCE METADATA SERVICE")

    result = []

    for instance in instances:
        metadata = instance.get(
            "MetadataOptions",
            {},
        )

        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "State": metadata.get("State"),
                "HttpEndpoint": metadata.get(
                    "HttpEndpoint"
                ),
                "HttpTokens": metadata.get(
                    "HttpTokens"
                ),
                "HttpPutResponseHopLimit": metadata.get(
                    "HttpPutResponseHopLimit"
                ),
                "HttpProtocolIpv6": metadata.get(
                    "HttpProtocolIpv6"
                ),
                "InstanceMetadataTags": metadata.get(
                    "InstanceMetadataTags"
                ),
            }
        )

    pretty(result)


# ============================================================
# Monitoring
# ============================================================

def show_monitoring(
    instances: list[dict[str, Any]],
) -> None:

    section("MONITORING / PERFORMANCE")

    result = []

    for instance in instances:
        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "Monitoring": get_nested(
                    instance,
                    "Monitoring",
                    "State",
                ),
                "EbsOptimized": instance.get(
                    "EbsOptimized"
                ),
            }
        )

    pretty(result)


# ============================================================
# Network Interfaces
# ============================================================

def show_network_interfaces(
    instances: list[dict[str, Any]],
) -> None:

    section("NETWORK INTERFACES")

    result = []

    for instance in instances:
        interfaces = []

        for interface in instance.get(
            "NetworkInterfaces",
            [],
        ):
            association = interface.get(
                "Association",
                {},
            )

            interfaces.append(
                {
                    "NetworkInterfaceId": interface.get(
                        "NetworkInterfaceId"
                    ),
                    "Status": interface.get("Status"),
                    "SubnetId": interface.get("SubnetId"),
                    "VpcId": interface.get("VpcId"),
                    "PrivateIpAddress": interface.get(
                        "PrivateIpAddress"
                    ),
                    "PublicIpAddress": association.get(
                        "PublicIp"
                    ),
                    "SourceDestCheck": interface.get(
                        "SourceDestCheck"
                    ),
                    "Groups": interface.get("Groups", []),
                }
            )

        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "Interfaces": interfaces,
            }
        )

    pretty(result)


# ============================================================
# Block Device Mapping
# ============================================================

def show_block_devices(
    instances: list[dict[str, Any]],
) -> None:

    section("BLOCK DEVICE MAPPING")

    result = []

    for instance in instances:
        result.append(
            {
                "InstanceId": instance.get("InstanceId"),
                "RootDeviceName": instance.get(
                    "RootDeviceName"
                ),
                "BlockDeviceMappings": instance.get(
                    "BlockDeviceMappings",
                    [],
                ),
            }
        )

    pretty(result)


# ============================================================
# EBS Volumes
# ============================================================

def show_ebs_volumes(
    ec2: Any,
    instances: list[dict[str, Any]],
) -> None:

    section("EBS VOLUMES")

    volume_ids: set[str] = set()

    for instance in instances:
        for mapping in instance.get(
            "BlockDeviceMappings",
            [],
        ):
            volume_id = get_nested(
                mapping,
                "Ebs",
                "VolumeId",
            )

            if volume_id:
                volume_ids.add(volume_id)

    if not volume_ids:
        warn("No EBS volumes found.")
        return

    try:
        response = ec2.describe_volumes(
            VolumeIds=sorted(volume_ids)
        )

    except (ClientError, BotoCoreError) as exc:
        warn(f"Unable to retrieve EBS volumes: {exc}")
        return

    result = []

    for volume in response.get("Volumes", []):
        result.append(
            {
                "VolumeId": volume.get("VolumeId"),
                "VolumeType": volume.get("VolumeType"),
                "SizeGiB": volume.get("Size"),
                "Encrypted": volume.get("Encrypted"),
                "KmsKeyId": volume.get("KmsKeyId"),
                "State": volume.get("State"),
                "AvailabilityZone": volume.get(
                    "AvailabilityZone"
                ),
                "Iops": volume.get("Iops"),
                "Throughput": volume.get("Throughput"),
                "Attachments": volume.get(
                    "Attachments",
                    [],
                ),
                "Tags": tags_to_dict(
                    volume.get("Tags")
                ),
            }
        )

    pretty(result)


# ============================================================
# Instance Status
# ============================================================

def show_instance_status(
    ec2: Any,
    instances: list[dict[str, Any]],
) -> None:

    section("INSTANCE STATUS")

    instance_ids = [
        instance["InstanceId"]
        for instance in instances
        if instance.get("InstanceId")
    ]

    if not instance_ids:
        warn("No instance IDs available.")
        return

    try:
        response = ec2.describe_instance_status(
            InstanceIds=instance_ids,
            IncludeAllInstances=True,
        )

    except (ClientError, BotoCoreError) as exc:
        warn(
            "Unable to retrieve instance status. "
            "This may be a LocalStack emulation limitation: "
            f"{exc}"
        )
        return

    statuses = response.get(
        "InstanceStatuses",
        [],
    )

    if not statuses:
        warn(
            "No instance status information returned. "
            "LocalStack may not emulate EC2 health checks."
        )
        return

    result = []

    for status in statuses:
        result.append(
            {
                "InstanceId": status.get("InstanceId"),
                "InstanceState": get_nested(
                    status,
                    "InstanceState",
                    "Name",
                ),
                "SystemStatus": get_nested(
                    status,
                    "SystemStatus",
                    "Status",
                ),
                "InstanceStatus": get_nested(
                    status,
                    "InstanceStatus",
                    "Status",
                ),
            }
        )

    pretty(result)


# ============================================================
# Tags
# ============================================================

def show_instance_tags(
    instances: list[dict[str, Any]],
) -> None:

    section("INSTANCE TAGS")

    for instance in instances:
        instance_id = instance.get("InstanceId")

        print()
        info(f"Instance: {instance_id}")

        pretty(
            tags_to_dict(
                instance.get("Tags")
            )
        )


# ============================================================
# Placement Overview
# ============================================================

def show_placement_overview(
    instances: list[dict[str, Any]],
) -> None:

    section("APPLICATION PLACEMENT OVERVIEW")

    result = []

    for instance in instances:
        tags = tags_to_dict(instance.get("Tags"))

        result.append(
            {
                "SubnetRole": tags.get("SubnetRole"),
                "InstanceId": instance.get("InstanceId"),
                "AvailabilityZone": get_nested(
                    instance,
                    "Placement",
                    "AvailabilityZone",
                ),
                "SubnetId": instance.get("SubnetId"),
                "PrivateIpAddress": instance.get(
                    "PrivateIpAddress"
                ),
                "PublicIpAddress": instance.get(
                    "PublicIpAddress"
                ),
            }
        )

    result.sort(
        key=lambda item: item.get("SubnetRole") or ""
    )

    pretty(result)


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("EC2 INSPECTION")

    info(f"Project             : {PROJECT_NAME}")
    info(f"Environment         : {ENVIRONMENT}")
    info(f"AWS region          : {AWS_REGION}")
    info(f"LocalStack endpoint : {LOCALSTACK_ENDPOINT}")

    try:
        ec2 = get_ec2_client()

        instances = discover_application_instances(
            ec2
        )

    except (ClientError, BotoCoreError) as exc:
        error(f"EC2 inspection failed: {exc}")
        return 1

    except Exception as exc:
        error(
            f"Unexpected EC2 inspection error: "
            f"{type(exc).__name__}: {exc}"
        )
        return 1

    section("APPLICATION EC2 DISCOVERY")

    if not instances:
        info(
            "No application EC2 instances found "
            "for the current project/environment."
        )
        return 0

    info(
        f"Application EC2 instance count: "
        f"{len(instances)}"
    )

    info(
        "Instance IDs: "
        + ", ".join(
            instance.get("InstanceId", "<unknown>")
            for instance in instances
        )
    )

    show_instance_summary(instances)

    show_placement_overview(instances)

    show_platform(instances)

    show_network(instances)

    show_security_groups(
        ec2,
        instances,
    )

    show_iam_instance_profiles(instances)

    show_metadata_options(instances)

    show_monitoring(instances)

    show_network_interfaces(instances)

    show_block_devices(instances)

    show_ebs_volumes(
        ec2,
        instances,
    )

    show_instance_status(
        ec2,
        instances,
    )

    show_instance_tags(instances)

    section("EC2 INSPECTION COMPLETE")

    print("[SUCCESS] EC2 inspection completed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())