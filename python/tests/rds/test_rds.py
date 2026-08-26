from __future__ import annotations

import os
from typing import Any

import boto3
import pytest
from botocore.config import Config

AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-1")
LOCALSTACK_ENDPOINT = os.getenv(
    "LOCALSTACK_ENDPOINT",
    "http://localhost:4566",
)

PROJECT_NAME = os.getenv(
    "PROJECT_NAME",
    "aws-enterprise-lab",
)

ENVIRONMENT = os.getenv(
    "ENVIRONMENT",
    "localstack",
)

DB_IDENTIFIER = os.getenv(
    "RDS_DB_IDENTIFIER",
    f"{PROJECT_NAME}-{ENVIRONMENT}-mysql",
)

EXPECTED_ENGINE = os.getenv(
    "RDS_EXPECTED_ENGINE",
    "mysql",
)

EXPECTED_INSTANCE_CLASS = os.getenv(
    "RDS_EXPECTED_INSTANCE_CLASS",
    "db.t3.micro",
)

EXPECTED_DATABASE_NAME = os.getenv(
    "RDS_EXPECTED_DATABASE_NAME",
    "appdb",
)

EXPECTED_BACKUP_RETENTION = int(
    os.getenv(
        "RDS_EXPECTED_BACKUP_RETENTION",
        "7",
    )
)

EXPECTED_STORAGE_TYPE = os.getenv(
    "RDS_EXPECTED_STORAGE_TYPE",
    "gp3",
)

EXPECTED_MULTI_AZ = (
    os.getenv(
        "RDS_EXPECTED_MULTI_AZ",
        "false",
    ).lower()
    == "true"
)

EXPECTED_PUBLICLY_ACCESSIBLE = (
    os.getenv(
        "RDS_EXPECTED_PUBLICLY_ACCESSIBLE",
        "false",
    ).lower()
    == "true"
)

EXPECTED_STORAGE_ENCRYPTED = (
    os.getenv(
        "RDS_EXPECTED_STORAGE_ENCRYPTED",
        "true",
    ).lower()
    == "true"
)

EXPECTED_DELETION_PROTECTION = (
    os.getenv(
        "RDS_EXPECTED_DELETION_PROTECTION",
        "false",
    ).lower()
    == "true"
)

EXPECTED_SUBNET_COUNT = int(
    os.getenv(
        "RDS_EXPECTED_SUBNET_COUNT",
        "2",
    )
)

@pytest.fixture(scope="session")
def rds_client():
    return boto3.client(
        "rds",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
        aws_access_key_id=os.getenv(
            "AWS_ACCESS_KEY_ID",
            "test",
        ),
        aws_secret_access_key=os.getenv(
            "AWS_SECRET_ACCESS_KEY",
            "test",
        ),
        aws_session_token=os.getenv(
            "AWS_SESSION_TOKEN"
        ),
        config=Config(
            retries={
                "max_attempts": 3,
                "mode": "standard",
            }
        ),
    )

@pytest.fixture(scope="session")
def db_instance(
    rds_client,
) -> dict[str, Any]:
    response = rds_client.describe_db_instances(
        DBInstanceIdentifier=DB_IDENTIFIER
    )

    instances = response.get(
        "DBInstances",
        [],
    )

    assert instances, (
        f"RDS instance not found: {DB_IDENTIFIER}"
    )

    return instances[0]

@pytest.fixture(scope="session")
def db_subnet_group(
    rds_client,
    db_instance: dict[str, Any],
) -> dict[str, Any]:
    subnet_group_data = (
        db_instance.get("DBSubnetGroup")
        or {}
    )

    subnet_group_name = (
        subnet_group_data.get(
            "DBSubnetGroupName"
        )
    )

    assert subnet_group_name, (
        "DB subnet group name is missing "
        "from RDS response"
    )

    response = (
        rds_client.describe_db_subnet_groups(
            DBSubnetGroupName=subnet_group_name
        )
    )

    groups = response.get(
        "DBSubnetGroups",
        [],
    )

    assert groups, (
        f"DB subnet group not found: "
        f"{subnet_group_name}"
    )

    return groups[0]

@pytest.fixture(scope="session")
def db_tags(
    rds_client,
    db_instance: dict[str, Any],
) -> dict[str, str]:
    resource_arn = db_instance.get(
        "DBInstanceArn"
    )

    assert resource_arn, (
        "DB instance ARN is missing "
        "from RDS response"
    )

    response = (
        rds_client.list_tags_for_resource(
            ResourceName=resource_arn
        )
    )

    return {
        tag["Key"]: tag.get("Value", "")
        for tag in response.get(
            "TagList",
            [],
        )
        if "Key" in tag
    }

def test_db_instance_exists(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("DBInstanceIdentifier")
        == DB_IDENTIFIER
    )


def test_db_instance_status_available(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("DBInstanceStatus")
        == "available"
    )


def test_engine(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("Engine")
        == EXPECTED_ENGINE
    )


def test_instance_class(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("DBInstanceClass")
        == EXPECTED_INSTANCE_CLASS
    )


def test_database_name(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("DBName")
        == EXPECTED_DATABASE_NAME
    )


def test_publicly_accessible(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("PubliclyAccessible")
        == EXPECTED_PUBLICLY_ACCESSIBLE
    )


def test_multi_az(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("MultiAZ")
        == EXPECTED_MULTI_AZ
    )


def test_storage_type(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("StorageType")
        == EXPECTED_STORAGE_TYPE
    )


def test_storage_encrypted(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get("StorageEncrypted")
        == EXPECTED_STORAGE_ENCRYPTED
    )


def test_allocated_storage(
    db_instance: dict[str, Any],
) -> None:
    allocated_storage = (
        db_instance.get("AllocatedStorage")
    )

    assert isinstance(
        allocated_storage,
        int,
    )

    assert allocated_storage >= 20


def test_backup_retention(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get(
            "BackupRetentionPeriod"
        )
        == EXPECTED_BACKUP_RETENTION
    )


def test_deletion_protection(
    db_instance: dict[str, Any],
) -> None:
    assert (
        db_instance.get(
            "DeletionProtection"
        )
        == EXPECTED_DELETION_PROTECTION
    )


def test_db_subnet_group_status(
    db_subnet_group: dict[str, Any],
) -> None:
    assert (
        db_subnet_group.get(
            "SubnetGroupStatus"
        )
        == "Complete"
    )


def test_db_subnet_count(
    db_subnet_group: dict[str, Any],
) -> None:
    subnets = db_subnet_group.get(
        "Subnets",
        [],
    )

    assert (
        len(subnets)
        >= EXPECTED_SUBNET_COUNT
    )


def test_db_subnets_multi_az(
    db_subnet_group: dict[str, Any],
) -> None:
    subnets = db_subnet_group.get(
        "Subnets",
        [],
    )

    availability_zones = {
        (
            subnet.get(
                "SubnetAvailabilityZone"
            )
            or {}
        ).get("Name")
        for subnet in subnets
    }

    availability_zones.discard(None)

    assert len(availability_zones) >= 2


def test_security_group_attached(
    db_instance: dict[str, Any],
) -> None:
    security_groups = [
        sg.get("VpcSecurityGroupId")
        for sg in db_instance.get(
            "VpcSecurityGroups",
            [],
        )
        if sg.get("VpcSecurityGroupId")
    ]

    assert security_groups


@pytest.mark.parametrize(
    ("tag_key", "expected_value"),
    [
        (
            "Project",
            PROJECT_NAME,
        ),
        (
            "Environment",
            ENVIRONMENT,
        ),
        (
            "Service",
            "rds",
        ),
        (
            "Component",
            "database",
        ),
        (
            "Tier",
            "private-db",
        ),
    ],
)
def test_required_tags(
    db_tags: dict[str, str],
    tag_key: str,
    expected_value: str,
) -> None:
    assert (
        db_tags.get(tag_key)
        == expected_value
    )