from __future__ import annotations

import os
import sys
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
    EndpointConnectionError,
)


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


PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def get_rds_client():
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


def pass_check(message: str) -> None:
    global PASS_COUNT
    PASS_COUNT += 1
    print(f"[PASS] {message}")


def warn_check(message: str) -> None:
    global WARN_COUNT
    WARN_COUNT += 1
    print(f"[WARN] {message}")


def fail_check(message: str) -> None:
    global FAIL_COUNT
    FAIL_COUNT += 1
    print(f"[FAIL] {message}")


def get_db_instance(
    rds_client,
) -> dict[str, Any]:
    response = rds_client.describe_db_instances(
        DBInstanceIdentifier=DB_IDENTIFIER
    )

    instances = response.get(
        "DBInstances",
        [],
    )

    if not instances:
        raise RuntimeError(
            f"RDS instance not found: {DB_IDENTIFIER}"
        )

    return instances[0]


def get_db_subnet_group(
    rds_client,
    subnet_group_name: str,
) -> dict[str, Any]:
    response = rds_client.describe_db_subnet_groups(
        DBSubnetGroupName=subnet_group_name
    )

    groups = response.get(
        "DBSubnetGroups",
        [],
    )

    if not groups:
        raise RuntimeError(
            "RDS DB subnet group not found: "
            f"{subnet_group_name}"
        )

    return groups[0]


def get_tags(
    rds_client,
    resource_arn: str,
) -> dict[str, str]:
    response = rds_client.list_tags_for_resource(
        ResourceName=resource_arn
    )

    return {
        tag["Key"]: tag.get("Value", "")
        for tag in response.get("TagList", [])
        if "Key" in tag
    }


def validate_identity(
    db: dict[str, Any],
) -> None:
    identifier = db.get("DBInstanceIdentifier")

    if identifier == DB_IDENTIFIER:
        pass_check(
            f"DB identifier is correct: {identifier}"
        )
    else:
        fail_check(
            f"DB identifier={identifier}, "
            f"expected={DB_IDENTIFIER}"
        )

    status = db.get("DBInstanceStatus")

    if status == "available":
        pass_check(
            "RDS instance status is available"
        )
    else:
        warn_check(
            f"RDS instance status is {status}"
        )


def validate_engine(
    db: dict[str, Any],
) -> None:
    engine = db.get("Engine")

    if engine == EXPECTED_ENGINE:
        pass_check(
            f"Database engine is correct: {engine}"
        )
    else:
        fail_check(
            f"engine={engine}, "
            f"expected={EXPECTED_ENGINE}"
        )

    instance_class = db.get("DBInstanceClass")

    if instance_class == EXPECTED_INSTANCE_CLASS:
        pass_check(
            "DB instance class is correct: "
            f"{instance_class}"
        )
    else:
        fail_check(
            f"instance_class={instance_class}, "
            f"expected={EXPECTED_INSTANCE_CLASS}"
        )

    database_name = db.get("DBName")

    if database_name == EXPECTED_DATABASE_NAME:
        pass_check(
            f"Database name is correct: "
            f"{database_name}"
        )
    else:
        fail_check(
            f"database_name={database_name}, "
            f"expected={EXPECTED_DATABASE_NAME}"
        )


def validate_network(
    db: dict[str, Any],
    subnet_group: dict[str, Any],
) -> None:
    publicly_accessible = db.get(
        "PubliclyAccessible"
    )

    if (
        publicly_accessible
        == EXPECTED_PUBLICLY_ACCESSIBLE
    ):
        pass_check(
            "Public accessibility is correct: "
            f"{publicly_accessible}"
        )
    else:
        fail_check(
            "publicly_accessible="
            f"{publicly_accessible}, "
            "expected="
            f"{EXPECTED_PUBLICLY_ACCESSIBLE}"
        )

    subnet_group_status = subnet_group.get(
        "SubnetGroupStatus"
    )

    if subnet_group_status == "Complete":
        pass_check(
            "DB subnet group status is Complete"
        )
    else:
        warn_check(
            "DB subnet group status="
            f"{subnet_group_status}"
        )

    subnets = subnet_group.get(
        "Subnets",
        [],
    )

    if len(subnets) >= EXPECTED_SUBNET_COUNT:
        pass_check(
            "DB subnet group contains "
            f"{len(subnets)} subnet(s)"
        )
    else:
        fail_check(
            "DB subnet group contains "
            f"{len(subnets)} subnet(s), "
            f"expected at least "
            f"{EXPECTED_SUBNET_COUNT}"
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

    if len(availability_zones) >= 2:
        pass_check(
            "DB subnets span multiple "
            "Availability Zones: "
            f"{sorted(availability_zones)}"
        )
    else:
        fail_check(
            "DB subnet group does not span "
            "at least two Availability Zones"
        )

    security_groups = [
        sg.get("VpcSecurityGroupId")
        for sg in db.get(
            "VpcSecurityGroups",
            [],
        )
        if sg.get("VpcSecurityGroupId")
    ]

    if security_groups:
        pass_check(
            "RDS has VPC security group(s): "
            f"{security_groups}"
        )
    else:
        fail_check(
            "RDS has no VPC security groups"
        )


def validate_availability(
    db: dict[str, Any],
) -> None:
    multi_az = db.get("MultiAZ")

    if multi_az == EXPECTED_MULTI_AZ:
        pass_check(
            f"Multi-AZ setting is correct: "
            f"{multi_az}"
        )
    else:
        fail_check(
            f"multi_az={multi_az}, "
            f"expected={EXPECTED_MULTI_AZ}"
        )


def validate_storage(
    db: dict[str, Any],
) -> None:
    storage_type = db.get("StorageType")

    if storage_type == EXPECTED_STORAGE_TYPE:
        pass_check(
            f"Storage type is correct: "
            f"{storage_type}"
        )
    else:
        fail_check(
            f"storage_type={storage_type}, "
            f"expected={EXPECTED_STORAGE_TYPE}"
        )

    encrypted = db.get(
        "StorageEncrypted"
    )

    if encrypted == EXPECTED_STORAGE_ENCRYPTED:
        pass_check(
            "Storage encryption setting "
            f"is correct: {encrypted}"
        )
    else:
        fail_check(
            f"storage_encrypted={encrypted}, "
            f"expected="
            f"{EXPECTED_STORAGE_ENCRYPTED}"
        )

    allocated_storage = db.get(
        "AllocatedStorage"
    )

    if (
        isinstance(
            allocated_storage,
            int,
        )
        and allocated_storage >= 20
    ):
        pass_check(
            "Allocated storage is valid: "
            f"{allocated_storage} GiB"
        )
    else:
        fail_check(
            "Allocated storage is invalid: "
            f"{allocated_storage}"
        )


def validate_backup(
    db: dict[str, Any],
) -> None:
    retention = db.get(
        "BackupRetentionPeriod"
    )

    if retention == EXPECTED_BACKUP_RETENTION:
        pass_check(
            "Backup retention period "
            f"is correct: {retention} days"
        )
    else:
        fail_check(
            f"backup_retention={retention}, "
            f"expected="
            f"{EXPECTED_BACKUP_RETENTION}"
        )


def validate_protection(
    db: dict[str, Any],
) -> None:
    deletion_protection = db.get(
        "DeletionProtection"
    )

    if (
        deletion_protection
        == EXPECTED_DELETION_PROTECTION
    ):
        pass_check(
            "Deletion protection setting "
            f"is correct: "
            f"{deletion_protection}"
        )
    else:
        fail_check(
            "deletion_protection="
            f"{deletion_protection}, "
            "expected="
            f"{EXPECTED_DELETION_PROTECTION}"
        )


def validate_tags(
    tags: dict[str, str],
) -> None:
    expected_tags = {
        "Project": PROJECT_NAME,
        "Environment": ENVIRONMENT,
        "Service": "rds",
        "Component": "database",
        "Tier": "private-db",
    }

    for key, expected_value in expected_tags.items():
        actual_value = tags.get(key)

        if actual_value == expected_value:
            pass_check(
                f"Tag {key} is correct: "
                f"{actual_value}"
            )
        else:
            fail_check(
                f"Tag {key}={actual_value}, "
                f"expected={expected_value}"
            )


def print_summary() -> None:
    print()
    print("=" * 72)
    print("RDS Validation Summary")
    print("=" * 72)
    print(f"PASS : {PASS_COUNT}")
    print(f"WARN : {WARN_COUNT}")
    print(f"FAIL : {FAIL_COUNT}")


def main() -> int:
    print("RDS Validation")
    print(
        f"DB Identifier : {DB_IDENTIFIER}"
    )
    print(
        f"Region        : {AWS_REGION}"
    )
    print(
        f"Endpoint      : {LOCALSTACK_ENDPOINT}"
    )
    print()

    try:
        rds_client = get_rds_client()

        db = get_db_instance(
            rds_client
        )

        subnet_group_data = (
            db.get("DBSubnetGroup")
            or {}
        )

        subnet_group_name = (
            subnet_group_data.get(
                "DBSubnetGroupName"
            )
        )

        if not subnet_group_name:
            raise RuntimeError(
                "DB subnet group name "
                "is missing from RDS response"
            )

        subnet_group = get_db_subnet_group(
            rds_client,
            subnet_group_name,
        )

        resource_arn = db.get(
            "DBInstanceArn"
        )

        if not resource_arn:
            raise RuntimeError(
                "DB instance ARN is missing "
                "from RDS response"
            )

        tags = get_tags(
            rds_client,
            resource_arn,
        )

        validate_identity(db)
        validate_engine(db)
        validate_network(
            db,
            subnet_group,
        )
        validate_availability(db)
        validate_storage(db)
        validate_backup(db)
        validate_protection(db)
        validate_tags(tags)

        print_summary()

        if FAIL_COUNT > 0:
            return 1

        return 0

    except EndpointConnectionError as exc:
        print(
            "[ERROR] Cannot connect to "
            f"LocalStack: {exc}",
            file=sys.stderr,
        )
        return 1

    except ClientError as exc:
        error = exc.response.get(
            "Error",
            {},
        )

        code = error.get(
            "Code",
            "Unknown",
        )

        message = error.get(
            "Message",
            str(exc),
        )

        print(
            "[ERROR] AWS API error: "
            f"{code}: {message}",
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