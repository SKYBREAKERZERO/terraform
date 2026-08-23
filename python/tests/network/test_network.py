from __future__ import annotations

from typing import Any

import pytest
from botocore.exceptions import BotoCoreError, ClientError

from common.aws_clients import get_ec2_client
from common.config import Config


# ============================================================
# Configuration
# ============================================================

PROJECT_NAME = Config.PROJECT_NAME
ENVIRONMENT = Config.ENVIRONMENT
AWS_REGION = Config.AWS_REGION

PROJECT_PREFIX = f"{PROJECT_NAME}-{ENVIRONMENT}"

EXPECTED_VPC_CIDR = "10.0.0.0/16"

EXPECTED_SUBNETS = {
    "public-a": {
        "cidr": "10.0.1.0/24",
        "az": f"{AWS_REGION}a",
        "tier": "public",
        "map_public_ip": True,
    },
    "public-c": {
        "cidr": "10.0.2.0/24",
        "az": f"{AWS_REGION}c",
        "tier": "public",
        "map_public_ip": True,
    },
    "app-a": {
        "cidr": "10.0.101.0/24",
        "az": f"{AWS_REGION}a",
        "tier": "private-app",
        "map_public_ip": False,
    },
    "app-c": {
        "cidr": "10.0.102.0/24",
        "az": f"{AWS_REGION}c",
        "tier": "private-app",
        "map_public_ip": False,
    },
    "db-a": {
        "cidr": "10.0.201.0/24",
        "az": f"{AWS_REGION}a",
        "tier": "private-db",
        "map_public_ip": False,
    },
    "db-c": {
        "cidr": "10.0.202.0/24",
        "az": f"{AWS_REGION}c",
        "tier": "private-db",
        "map_public_ip": False,
    },
}


# ============================================================
# Helpers
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


def find_default_route(
    route_table: dict[str, Any],
) -> dict[str, Any] | None:

    for route in route_table.get("Routes", []):
        if route.get("DestinationCidrBlock") == "0.0.0.0/0":
            return route

    return None


# ============================================================
# Fixtures
# ============================================================

@pytest.fixture(scope="module")
def ec2() -> Any:

    try:
        client = get_ec2_client()

        client.describe_vpcs(
            MaxResults=5
        )

        return client

    except (
        ClientError,
        BotoCoreError,
        Exception,
    ) as exc:
        pytest.fail(
            f"Unable to connect to LocalStack EC2: {exc}"
        )


@pytest.fixture(scope="module")
def project_vpc(
    ec2: Any,
) -> dict[str, Any]:

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

    assert len(vpcs) == 1, (
        f"Expected exactly one project VPC, "
        f"found={len(vpcs)}"
    )

    return vpcs[0]


@pytest.fixture(scope="module")
def project_subnets(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> dict[str, dict[str, Any]]:

    vpc_id = project_vpc["VpcId"]

    response = ec2.describe_subnets(
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
        ]
    )

    result: dict[str, dict[str, Any]] = {}

    for subnet in response.get(
        "Subnets",
        [],
    ):
        tags = tags_to_dict(
            subnet.get("Tags")
        )

        name = tags.get("Name")

        if not name:
            continue

        prefix = f"{PROJECT_PREFIX}-"

        if not name.startswith(prefix):
            continue

        subnet_role = name[len(prefix):]

        result[subnet_role] = subnet

    return result


@pytest.fixture(scope="module")
def subnet_route_tables(
    ec2: Any,
    project_subnets: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:

    result: dict[str, dict[str, Any]] = {}

    for subnet_role, subnet in (
        project_subnets.items()
    ):
        subnet_id = subnet["SubnetId"]

        response = ec2.describe_route_tables(
            Filters=[
                {
                    "Name": "association.subnet-id",
                    "Values": [subnet_id],
                }
            ]
        )

        route_tables = response.get(
            "RouteTables",
            [],
        )

        assert len(route_tables) == 1, (
            f"{subnet_role} expected exactly one "
            f"associated route table, "
            f"found={len(route_tables)}"
        )

        result[subnet_role] = route_tables[0]

    return result


# ============================================================
# VPC Tests
# ============================================================

def test_vpc_exists(
    project_vpc: dict[str, Any],
) -> None:

    assert project_vpc.get("VpcId")


def test_vpc_cidr(
    project_vpc: dict[str, Any],
) -> None:

    assert (
        project_vpc.get("CidrBlock")
        == EXPECTED_VPC_CIDR
    )


def test_vpc_state(
    project_vpc: dict[str, Any],
) -> None:

    assert (
        project_vpc.get("State")
        == "available"
    )


def test_vpc_is_not_default(
    project_vpc: dict[str, Any],
) -> None:

    assert (
        project_vpc.get("IsDefault")
        is False
    )


def test_vpc_tags(
    project_vpc: dict[str, Any],
) -> None:

    tags = tags_to_dict(
        project_vpc.get("Tags")
    )

    assert tags.get("Project") == PROJECT_NAME
    assert tags.get("Environment") == ENVIRONMENT
    assert tags.get("ManagedBy") == "terraform"


# ============================================================
# VPC DNS Tests
# ============================================================

def test_vpc_dns_support_enabled(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> None:

    response = ec2.describe_vpc_attribute(
        VpcId=project_vpc["VpcId"],
        Attribute="enableDnsSupport",
    )

    assert (
        response
        .get("EnableDnsSupport", {})
        .get("Value")
        is True
    )


def test_vpc_dns_hostnames_enabled(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> None:

    response = ec2.describe_vpc_attribute(
        VpcId=project_vpc["VpcId"],
        Attribute="enableDnsHostnames",
    )

    assert (
        response
        .get("EnableDnsHostnames", {})
        .get("Value")
        is True
    )


# ============================================================
# Subnet Tests
# ============================================================

def test_expected_subnet_count(
    project_subnets: dict[str, dict[str, Any]],
) -> None:

    assert len(project_subnets) == len(
        EXPECTED_SUBNETS
    )


@pytest.mark.parametrize(
    "subnet_role",
    EXPECTED_SUBNETS.keys(),
)
def test_subnet_exists(
    project_subnets: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    assert subnet_role in project_subnets


@pytest.mark.parametrize(
    "subnet_role",
    EXPECTED_SUBNETS.keys(),
)
def test_subnet_cidr(
    project_subnets: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    subnet = project_subnets[subnet_role]
    expected = EXPECTED_SUBNETS[subnet_role]

    assert (
        subnet.get("CidrBlock")
        == expected["cidr"]
    )


@pytest.mark.parametrize(
    "subnet_role",
    EXPECTED_SUBNETS.keys(),
)
def test_subnet_availability_zone(
    project_subnets: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    subnet = project_subnets[subnet_role]
    expected = EXPECTED_SUBNETS[subnet_role]

    assert (
        subnet.get("AvailabilityZone")
        == expected["az"]
    )


@pytest.mark.parametrize(
    "subnet_role",
    EXPECTED_SUBNETS.keys(),
)
def test_subnet_public_ip_behavior(
    project_subnets: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    subnet = project_subnets[subnet_role]
    expected = EXPECTED_SUBNETS[subnet_role]

    assert (
        subnet.get("MapPublicIpOnLaunch")
        == expected["map_public_ip"]
    )


@pytest.mark.parametrize(
    "subnet_role",
    EXPECTED_SUBNETS.keys(),
)
def test_subnet_tags(
    project_subnets: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    subnet = project_subnets[subnet_role]

    tags = tags_to_dict(
        subnet.get("Tags")
    )

    assert (
        tags.get("Name")
        == f"{PROJECT_PREFIX}-{subnet_role}"
    )

    assert tags.get("Project") == PROJECT_NAME
    assert tags.get("Environment") == ENVIRONMENT

    expected_tier = (
        EXPECTED_SUBNETS[
            subnet_role
        ]["tier"]
    )

    assert tags.get("Tier") == expected_tier


# ============================================================
# Internet Gateway Tests
# ============================================================

def test_single_internet_gateway_attached(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> None:

    vpc_id = project_vpc["VpcId"]

    response = ec2.describe_internet_gateways(
        Filters=[
            {
                "Name": "attachment.vpc-id",
                "Values": [vpc_id],
            }
        ]
    )

    gateways = response.get(
        "InternetGateways",
        [],
    )

    assert len(gateways) == 1


# ============================================================
# NAT Gateway Tests
# ============================================================

def test_single_nat_gateway(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> None:

    response = ec2.describe_nat_gateways(
        Filter=[
            {
                "Name": "vpc-id",
                "Values": [
                    project_vpc["VpcId"]
                ],
            }
        ]
    )

    nat_gateways = [
        gateway
        for gateway in response.get(
            "NatGateways",
            [],
        )
        if gateway.get("State")
        not in (
            "deleted",
            "deleting",
            "failed",
        )
    ]

    assert len(nat_gateways) == 1


def test_nat_gateway_is_in_public_a(
    ec2: Any,
    project_vpc: dict[str, Any],
    project_subnets: dict[str, dict[str, Any]],
) -> None:

    response = ec2.describe_nat_gateways(
        Filter=[
            {
                "Name": "vpc-id",
                "Values": [
                    project_vpc["VpcId"]
                ],
            }
        ]
    )

    nat_gateways = [
        gateway
        for gateway in response.get(
            "NatGateways",
            [],
        )
        if gateway.get("State")
        not in (
            "deleted",
            "deleting",
            "failed",
        )
    ]

    assert len(nat_gateways) == 1

    assert (
        nat_gateways[0].get("SubnetId")
        == project_subnets[
            "public-a"
        ]["SubnetId"]
    )


# ============================================================
# Public Route Tests
# ============================================================

@pytest.mark.parametrize(
    "subnet_role",
    (
        "public-a",
        "public-c",
    ),
)
def test_public_subnet_default_route_uses_igw(
    subnet_route_tables: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    route_table = subnet_route_tables[
        subnet_role
    ]

    route = find_default_route(
        route_table
    )

    assert route is not None

    gateway_id = route.get(
        "GatewayId"
    )

    assert gateway_id
    assert gateway_id.startswith("igw-")


# ============================================================
# Application Route Tests
# ============================================================

@pytest.mark.parametrize(
    "subnet_role",
    (
        "app-a",
        "app-c",
    ),
)
def test_application_subnet_default_route_uses_nat(
    subnet_route_tables: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    route_table = subnet_route_tables[
        subnet_role
    ]

    route = find_default_route(
        route_table
    )

    assert route is not None

    nat_gateway_id = route.get(
        "NatGatewayId"
    )

    assert nat_gateway_id
    assert nat_gateway_id.startswith("nat-")


# ============================================================
# Database Isolation Tests
# ============================================================

@pytest.mark.parametrize(
    "subnet_role",
    (
        "db-a",
        "db-c",
    ),
)
def test_database_subnet_has_no_default_internet_route(
    subnet_route_tables: dict[str, dict[str, Any]],
    subnet_role: str,
) -> None:

    route_table = subnet_route_tables[
        subnet_role
    ]

    route = find_default_route(
        route_table
    )

    assert route is None


# ============================================================
# Multi-AZ Tests
# ============================================================

def test_public_subnets_span_two_azs(
    project_subnets: dict[str, dict[str, Any]],
) -> None:

    azs = {
        project_subnets[
            subnet_role
        ]["AvailabilityZone"]
        for subnet_role in (
            "public-a",
            "public-c",
        )
    }

    assert len(azs) == 2


def test_application_subnets_span_two_azs(
    project_subnets: dict[str, dict[str, Any]],
) -> None:

    azs = {
        project_subnets[
            subnet_role
        ]["AvailabilityZone"]
        for subnet_role in (
            "app-a",
            "app-c",
        )
    }

    assert len(azs) == 2


def test_database_subnets_span_two_azs(
    project_subnets: dict[str, dict[str, Any]],
) -> None:

    azs = {
        project_subnets[
            subnet_role
        ]["AvailabilityZone"]
        for subnet_role in (
            "db-a",
            "db-c",
        )
    }

    assert len(azs) == 2


# ============================================================
# S3 Gateway Endpoint Tests
# ============================================================

def test_single_s3_gateway_endpoint(
    ec2: Any,
    project_vpc: dict[str, Any],
) -> None:

    service_name = (
        f"com.amazonaws.{AWS_REGION}.s3"
    )

    response = ec2.describe_vpc_endpoints(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [
                    project_vpc["VpcId"]
                ],
            },
            {
                "Name": "service-name",
                "Values": [service_name],
            },
            {
                "Name": "vpc-endpoint-type",
                "Values": ["Gateway"],
            },
        ]
    )

    endpoints = response.get(
        "VpcEndpoints",
        [],
    )

    assert len(endpoints) == 1


def test_s3_endpoint_attached_to_private_route_tables(
    ec2: Any,
    project_vpc: dict[str, Any],
    subnet_route_tables: dict[str, dict[str, Any]],
) -> None:

    service_name = (
        f"com.amazonaws.{AWS_REGION}.s3"
    )

    response = ec2.describe_vpc_endpoints(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [
                    project_vpc["VpcId"]
                ],
            },
            {
                "Name": "service-name",
                "Values": [service_name],
            },
            {
                "Name": "vpc-endpoint-type",
                "Values": ["Gateway"],
            },
        ]
    )

    endpoints = response.get(
        "VpcEndpoints",
        [],
    )

    assert len(endpoints) == 1

    endpoint_route_table_ids = set(
        endpoints[0].get(
            "RouteTableIds",
            [],
        )
    )

    expected_private_route_table_ids = {
        subnet_route_tables[
            subnet_role
        ]["RouteTableId"]
        for subnet_role in (
            "app-a",
            "app-c",
            "db-a",
            "db-c",
        )
    }

    assert (
        endpoint_route_table_ids
        == expected_private_route_table_ids
    )


def test_s3_endpoint_not_attached_to_public_route_table(
    ec2: Any,
    project_vpc: dict[str, Any],
    subnet_route_tables: dict[str, dict[str, Any]],
) -> None:

    service_name = (
        f"com.amazonaws.{AWS_REGION}.s3"
    )

    response = ec2.describe_vpc_endpoints(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [
                    project_vpc["VpcId"]
                ],
            },
            {
                "Name": "service-name",
                "Values": [service_name],
            },
        ]
    )

    endpoints = response.get(
        "VpcEndpoints",
        [],
    )

    assert len(endpoints) == 1

    endpoint_route_table_ids = set(
        endpoints[0].get(
            "RouteTableIds",
            [],
        )
    )

    public_route_table_ids = {
        subnet_route_tables[
            subnet_role
        ]["RouteTableId"]
        for subnet_role in (
            "public-a",
            "public-c",
        )
    }

    assert endpoint_route_table_ids.isdisjoint(
        public_route_table_ids
    )