from __future__ import annotations

import os
import sys
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError, EndpointConnectionError


AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-1")
LOCALSTACK_ENDPOINT = os.getenv("LOCALSTACK_ENDPOINT", "http://localhost:4566")

PROJECT_NAME = os.getenv("PROJECT_NAME", "aws-enterprise-lab")
ENVIRONMENT = os.getenv("ENVIRONMENT", "localstack")

DB_IDENTIFIER = os.getenv(
    "RDS_DB_IDENTIFIER",
    f"{PROJECT_NAME}-{ENVIRONMENT}-mysql",
)


def get_rds_client():
    return boto3.client(
        "rds",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY", "test"),
        aws_session_token=os.getenv("AWS_SESSION_TOKEN"),
        config=Config(
            retries={
                "max_attempts": 3,
                "mode": "standard",
            }
        ),
    )


def print_section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def format_value(value: Any) -> str:
    if value is None:
        return "-"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        if not value:
            return "-"
        return ", ".join(str(item) for item in value)
    return str(value)


def print_field(name: str, value: Any) -> None:
    print(f"{name:<32}: {format_value(value)}")


def get_db_instance(rds_client) -> dict[str, Any]:
    response = rds_client.describe_db_instances(
        DBInstanceIdentifier=DB_IDENTIFIER
    )

    instances = response.get("DBInstances", [])

    if not instances:
        raise RuntimeError(
            f"RDS instance not found: {DB_IDENTIFIER}"
        )

    return instances[0]


def get_db_subnet_group(
    rds_client,
    subnet_group_name: str | None,
) -> dict[str, Any] | None:
    if not subnet_group_name:
        return None

    response = rds_client.describe_db_subnet_groups(
        DBSubnetGroupName=subnet_group_name
    )

    subnet_groups = response.get("DBSubnetGroups", [])

    if not subnet_groups:
        return None

    return subnet_groups[0]


def get_tags(
    rds_client,
    resource_arn: str | None,
) -> dict[str, str]:
    if not resource_arn:
        return {}

    response = rds_client.list_tags_for_resource(
        ResourceName=resource_arn
    )

    return {
        tag["Key"]: tag.get("Value", "")
        for tag in response.get("TagList", [])
        if "Key" in tag
    }


def show_db_instance(db: dict[str, Any]) -> None:
    endpoint = db.get("Endpoint") or {}

    print_section("RDS DB Instance")

    print_field(
        "DB Identifier",
        db.get("DBInstanceIdentifier"),
    )
    print_field(
        "DB Instance ARN",
        db.get("DBInstanceArn"),
    )
    print_field(
        "Status",
        db.get("DBInstanceStatus"),
    )
    print_field(
        "Engine",
        db.get("Engine"),
    )
    print_field(
        "Engine Version",
        db.get("EngineVersion"),
    )
    print_field(
        "Instance Class",
        db.get("DBInstanceClass"),
    )
    print_field(
        "Database Name",
        db.get("DBName"),
    )

    print_field(
        "Endpoint",
        endpoint.get("Address"),
    )
    print_field(
        "Port",
        endpoint.get("Port"),
    )

    print_field(
        "Availability Zone",
        db.get("AvailabilityZone"),
    )
    print_field(
        "Multi-AZ",
        db.get("MultiAZ"),
    )
    print_field(
        "Publicly Accessible",
        db.get("PubliclyAccessible"),
    )


def show_network(db: dict[str, Any]) -> None:
    subnet_group = db.get("DBSubnetGroup") or {}

    security_groups = [
        sg.get("VpcSecurityGroupId")
        for sg in db.get("VpcSecurityGroups", [])
        if sg.get("VpcSecurityGroupId")
    ]

    print_section("Network")

    print_field(
        "Subnet Group",
        subnet_group.get("DBSubnetGroupName"),
    )
    print_field(
        "Subnet Group Status",
        subnet_group.get("SubnetGroupStatus"),
    )
    print_field(
        "VPC ID",
        subnet_group.get("VpcId"),
    )
    print_field(
        "Security Groups",
        security_groups,
    )


def show_subnets(
    subnet_group: dict[str, Any] | None,
) -> None:
    print_section("DB Subnets")

    if not subnet_group:
        print("No DB subnet group information available.")
        return

    subnets = subnet_group.get("Subnets", [])

    if not subnets:
        print("No subnets found.")
        return

    for subnet in subnets:
        availability_zone = (
            subnet.get("SubnetAvailabilityZone") or {}
        )

        print_field(
            "Subnet ID",
            subnet.get("SubnetIdentifier"),
        )
        print_field(
            "Availability Zone",
            availability_zone.get("Name"),
        )
        print_field(
            "Status",
            subnet.get("SubnetStatus"),
        )
        print("-" * 72)


def show_storage(db: dict[str, Any]) -> None:
    print_section("Storage")

    print_field(
        "Allocated Storage (GiB)",
        db.get("AllocatedStorage"),
    )
    print_field(
        "Max Allocated Storage",
        db.get("MaxAllocatedStorage"),
    )
    print_field(
        "Storage Type",
        db.get("StorageType"),
    )
    print_field(
        "Storage Encrypted",
        db.get("StorageEncrypted"),
    )
    print_field(
        "KMS Key ID",
        db.get("KmsKeyId"),
    )


def show_backup(db: dict[str, Any]) -> None:
    print_section("Backup / Maintenance")

    print_field(
        "Backup Retention (days)",
        db.get("BackupRetentionPeriod"),
    )
    print_field(
        "Backup Window",
        db.get("PreferredBackupWindow"),
    )
    print_field(
        "Maintenance Window",
        db.get("PreferredMaintenanceWindow"),
    )
    print_field(
        "Latest Restorable Time",
        db.get("LatestRestorableTime"),
    )


def show_monitoring(db: dict[str, Any]) -> None:
    print_section("Monitoring")

    print_field(
        "Monitoring Interval",
        db.get("MonitoringInterval"),
    )
    print_field(
        "Monitoring Role ARN",
        db.get("MonitoringRoleArn"),
    )
    print_field(
        "Performance Insights",
        db.get("PerformanceInsightsEnabled"),
    )
    print_field(
        "CloudWatch Logs",
        db.get("EnabledCloudwatchLogsExports"),
    )


def show_protection(db: dict[str, Any]) -> None:
    print_section("Protection")

    print_field(
        "Deletion Protection",
        db.get("DeletionProtection"),
    )
    print_field(
        "Auto Minor Upgrade",
        db.get("AutoMinorVersionUpgrade"),
    )


def show_tags(tags: dict[str, str]) -> None:
    print_section("Tags")

    if not tags:
        print("No tags found.")
        return

    for key in sorted(tags):
        print_field(key, tags[key])


def main() -> int:
    print("RDS Inventory")
    print_field("Region", AWS_REGION)
    print_field("Endpoint", LOCALSTACK_ENDPOINT)
    print_field("DB Identifier", DB_IDENTIFIER)

    try:
        rds_client = get_rds_client()

        db = get_db_instance(rds_client)

        subnet_group_name = (
            (db.get("DBSubnetGroup") or {})
            .get("DBSubnetGroupName")
        )

        subnet_group = get_db_subnet_group(
            rds_client,
            subnet_group_name,
        )

        tags = get_tags(
            rds_client,
            db.get("DBInstanceArn"),
        )

        show_db_instance(db)
        show_network(db)
        show_subnets(subnet_group)
        show_storage(db)
        show_backup(db)
        show_monitoring(db)
        show_protection(db)
        show_tags(tags)

        print()
        return 0

    except EndpointConnectionError as exc:
        print(
            f"[ERROR] Cannot connect to LocalStack: {exc}",
            file=sys.stderr,
        )
        return 1

    except ClientError as exc:
        error = exc.response.get("Error", {})
        code = error.get("Code", "Unknown")
        message = error.get("Message", str(exc))

        print(
            f"[ERROR] AWS API error: {code}: {message}",
            file=sys.stderr,
        )
        return 1

    except BotoCoreError as exc:
        print(
            f"[ERROR] boto3 error: {exc}",
            file=sys.stderr,
        )
        return 1

    except RuntimeError as exc:
        print(
            f"[ERROR] {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())