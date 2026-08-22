import os
import sys
from typing import Any

from botocore.exceptions import (
    BotoCoreError,
    ClientError,
    EndpointConnectionError,
)

from common.aws_clients import get_ec2_client
from common.config import Config


# ============================================================
# Runtime Configuration
# ============================================================

PROJECT_NAME = Config.PROJECT_NAME
ENVIRONMENT = Config.ENVIRONMENT
AWS_REGION = Config.AWS_REGION


# ============================================================
# Expected Network Configuration
# ============================================================

EXPECTED_VPC_CIDR = "10.0.0.0/16"

EXPECTED_SUBNETS = {
    "public-a": {
        "cidr": "10.0.1.0/24",
        "az": "ap-northeast-1a",
        "public": True,
        "tier": "public",
    },
    "public-c": {
        "cidr": "10.0.2.0/24",
        "az": "ap-northeast-1c",
        "public": True,
        "tier": "public",
    },
    "app-a": {
        "cidr": "10.0.101.0/24",
        "az": "ap-northeast-1a",
        "public": False,
        "tier": "private-app",
    },
    "app-c": {
        "cidr": "10.0.102.0/24",
        "az": "ap-northeast-1c",
        "public": False,
        "tier": "private-app",
    },
    "db-a": {
        "cidr": "10.0.201.0/24",
        "az": "ap-northeast-1a",
        "public": False,
        "tier": "private-db",
    },
    "db-c": {
        "cidr": "10.0.202.0/24",
        "az": "ap-northeast-1c",
        "public": False,
        "tier": "private-db",
    },
}

EXPECTED_NAT_GATEWAY_MODE = os.getenv(
    "NAT_GATEWAY_MODE",
    "single",
).lower()

REQUIRE_S3_ENDPOINT = os.getenv(
    "REQUIRE_S3_ENDPOINT",
    "true",
).lower() == "true"

REQUIRE_CUSTOM_NACLS = os.getenv(
    "REQUIRE_CUSTOM_NACLS",
    "false",
).lower() == "true"

REQUIRE_FLOW_LOGS = os.getenv(
    "REQUIRE_FLOW_LOGS",
    "false",
).lower() == "true"


# ============================================================
# Validation Result
# ============================================================

class ValidationResult:
    def __init__(self) -> None:
        self.pass_count = 0
        self.warn_count = 0
        self.fail_count = 0

    def passed(self, message: str) -> None:
        print(f"[PASS] {message}")
        self.pass_count += 1

    def warning(self, message: str) -> None:
        print(f"[WARN] {message}")
        self.warn_count += 1

    def failed(self, message: str) -> None:
        print(f"[FAIL] {message}")
        self.fail_count += 1

    @property
    def success(self) -> bool:
        return self.fail_count == 0


# ============================================================
# Generic Helpers
# ============================================================

def section(title: str) -> None:
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def get_tag(
    tags: list[dict[str, Any]] | None,
    key: str,
    default: str | None = None,
) -> str | None:
    if not tags:
        return default

    for tag in tags:
        if tag.get("Key") == key:
            return tag.get(
                "Value",
                default,
            )

    return default


def get_name(
    tags: list[dict[str, Any]] | None,
) -> str | None:
    return get_tag(
        tags,
        "Name",
    )


def get_project_prefix() -> str:
    return (
        f"{PROJECT_NAME}-"
        f"{ENVIRONMENT}"
    )


def get_expected_vpc_name() -> str:
    return (
        f"{get_project_prefix()}-vpc"
    )


def get_short_name(
    resource_name: str | None,
) -> str | None:
    if not resource_name:
        return None

    prefix = (
        f"{get_project_prefix()}-"
    )

    if resource_name.startswith(prefix):
        return resource_name[len(prefix):]

    return resource_name


def get_default_route(
    route_table: dict[str, Any],
) -> dict[str, Any] | None:
    for route in route_table.get(
        "Routes",
        [],
    ):
        if (
            route.get("DestinationCidrBlock")
            == "0.0.0.0/0"
        ):
            return route

    return None


def get_subnet_route_table(
    ec2,
    subnet_id: str,
) -> dict[str, Any] | None:
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

    if len(route_tables) != 1:
        return None

    return route_tables[0]


def get_subnets_by_tier(
    subnets: list[dict[str, Any]],
    tier: str,
) -> list[dict[str, Any]]:
    return [
        subnet
        for subnet in subnets
        if get_tag(
            subnet.get("Tags"),
            "Tier",
        )
        == tier
    ]


# ============================================================
# VPC
# ============================================================

def find_project_vpc(
    ec2,
) -> dict[str, Any] | None:
    expected_name = (
        get_expected_vpc_name()
    )

    response = ec2.describe_vpcs(
        Filters=[
            {
                "Name": "tag:Name",
                "Values": [expected_name],
            }
        ]
    )

    vpcs = response.get(
        "Vpcs",
        [],
    )

    if len(vpcs) != 1:
        return None

    return vpcs[0]


def validate_vpc(
    ec2,
    result: ValidationResult,
) -> dict[str, Any] | None:
    section("VPC VALIDATION")

    vpc = find_project_vpc(ec2)

    if not vpc:
        result.failed(
            "Expected exactly one VPC "
            f"with Name={get_expected_vpc_name()}"
        )
        return None

    vpc_id = vpc["VpcId"]

    result.passed(
        f"Project VPC exists: {vpc_id}"
    )

    # State

    state = vpc.get("State")

    if state == "available":
        result.passed(
            "VPC state=available"
        )
    else:
        result.failed(
            f"VPC state={state} "
            "expected=available"
        )

    # CIDR

    actual_cidr = vpc.get(
        "CidrBlock"
    )

    if actual_cidr == EXPECTED_VPC_CIDR:
        result.passed(
            f"VPC CIDR={EXPECTED_VPC_CIDR}"
        )
    else:
        result.failed(
            f"VPC CIDR={actual_cidr} "
            f"expected={EXPECTED_VPC_CIDR}"
        )

    # DNS Support

    dns_support_response = (
        ec2.describe_vpc_attribute(
            VpcId=vpc_id,
            Attribute="enableDnsSupport",
        )
    )

    dns_support = (
        dns_support_response
        .get("EnableDnsSupport", {})
        .get("Value", False)
    )

    if dns_support:
        result.passed(
            "VPC DNS support is enabled"
        )
    else:
        result.failed(
            "VPC DNS support is disabled"
        )

    # DNS Hostnames

    dns_hostnames_response = (
        ec2.describe_vpc_attribute(
            VpcId=vpc_id,
            Attribute="enableDnsHostnames",
        )
    )

    dns_hostnames = (
        dns_hostnames_response
        .get("EnableDnsHostnames", {})
        .get("Value", False)
    )

    if dns_hostnames:
        result.passed(
            "VPC DNS hostnames are enabled"
        )
    else:
        result.failed(
            "VPC DNS hostnames are disabled"
        )

    print(
        f"[INFO] VPC_ID={vpc_id}"
    )

    return vpc


# ============================================================
# Subnets
# ============================================================

def validate_subnets(
    ec2,
    result: ValidationResult,
    vpc_id: str,
) -> list[dict[str, Any]]:
    section("SUBNET VALIDATION")

    response = ec2.describe_subnets(
        Filters=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            }
        ]
    )

    subnets = response.get(
        "Subnets",
        [],
    )

    expected_count = len(
        EXPECTED_SUBNETS
    )

    if len(subnets) == expected_count:
        result.passed(
            f"Subnet count={expected_count}"
        )
    else:
        result.failed(
            f"Subnet count={len(subnets)} "
            f"expected={expected_count}"
        )

    actual_by_name: dict[
        str,
        dict[str, Any],
    ] = {}

    for subnet in subnets:
        full_name = get_name(
            subnet.get("Tags")
        )

        short_name = get_short_name(
            full_name
        )

        if short_name:
            actual_by_name[
                short_name
            ] = subnet

    for name, expected in (
        EXPECTED_SUBNETS.items()
    ):
        subnet = actual_by_name.get(
            name
        )

        if not subnet:
            result.failed(
                f"Subnet missing: {name}"
            )
            continue

        subnet_id = subnet[
            "SubnetId"
        ]

        result.passed(
            f"Subnet exists: "
            f"{name} ({subnet_id})"
        )

        # CIDR

        actual_cidr = subnet.get(
            "CidrBlock"
        )

        if (
            actual_cidr
            == expected["cidr"]
        ):
            result.passed(
                f"{name} CIDR="
                f"{expected['cidr']}"
            )
        else:
            result.failed(
                f"{name} CIDR="
                f"{actual_cidr} "
                f"expected="
                f"{expected['cidr']}"
            )

        # Availability Zone

        actual_az = subnet.get(
            "AvailabilityZone"
        )

        if actual_az == expected["az"]:
            result.passed(
                f"{name} AZ="
                f"{expected['az']}"
            )
        else:
            result.failed(
                f"{name} AZ="
                f"{actual_az} "
                f"expected="
                f"{expected['az']}"
            )

        # Public IP

        actual_public_ip = subnet.get(
            "MapPublicIpOnLaunch",
            False,
        )

        if (
            actual_public_ip
            == expected["public"]
        ):
            result.passed(
                f"{name} "
                "MapPublicIpOnLaunch="
                f"{actual_public_ip}"
            )
        else:
            result.failed(
                f"{name} "
                "MapPublicIpOnLaunch="
                f"{actual_public_ip} "
                "expected="
                f"{expected['public']}"
            )

        # Tier Tag

        actual_tier = get_tag(
            subnet.get("Tags"),
            "Tier",
        )

        if (
            actual_tier
            == expected["tier"]
        ):
            result.passed(
                f"{name} Tier="
                f"{actual_tier}"
            )
        else:
            result.failed(
                f"{name} Tier="
                f"{actual_tier} "
                "expected="
                f"{expected['tier']}"
            )

    return subnets


# ============================================================
# Internet Gateway
# ============================================================

def validate_internet_gateway(
    ec2,
    result: ValidationResult,
    vpc_id: str,
) -> str | None:
    section(
        "INTERNET GATEWAY VALIDATION"
    )

    response = (
        ec2.describe_internet_gateways(
            Filters=[
                {
                    "Name":
                    "attachment.vpc-id",
                    "Values": [vpc_id],
                }
            ]
        )
    )

    gateways = response.get(
        "InternetGateways",
        [],
    )

    if len(gateways) != 1:
        result.failed(
            "Internet Gateway count="
            f"{len(gateways)} "
            "expected=1"
        )
        return None

    gateway = gateways[0]

    igw_id = gateway[
        "InternetGatewayId"
    ]

    result.passed(
        f"Internet Gateway exists: "
        f"{igw_id}"
    )

    matching_attachment = None

    for attachment in gateway.get(
        "Attachments",
        [],
    ):
        if (
            attachment.get("VpcId")
            == vpc_id
        ):
            matching_attachment = (
                attachment
            )
            break

    if not matching_attachment:
        result.failed(
            f"IGW {igw_id} is not "
            f"attached to VPC {vpc_id}"
        )
        return igw_id

    attachment_state = (
        matching_attachment.get(
            "State"
        )
    )

    if attachment_state == "attached":
        result.passed(
            "Internet Gateway "
            "attachment state=attached"
        )
    else:
        result.failed(
            "Internet Gateway "
            f"attachment state="
            f"{attachment_state} "
            "expected=attached"
        )

    return igw_id


# ============================================================
# NAT Gateway
# ============================================================

def get_expected_nat_count() -> int:
    if (
        EXPECTED_NAT_GATEWAY_MODE
        == "none"
    ):
        return 0

    if (
        EXPECTED_NAT_GATEWAY_MODE
        == "single"
    ):
        return 1

    if (
        EXPECTED_NAT_GATEWAY_MODE
        == "one-per-az"
    ):
        public_azs = {
            config["az"]
            for config
            in EXPECTED_SUBNETS.values()
            if config["tier"]
            == "public"
        }

        return len(
            public_azs
        )

    raise ValueError(
        "NAT_GATEWAY_MODE must be "
        "none, single, or one-per-az"
    )


def validate_nat_gateways(
    ec2,
    result: ValidationResult,
    vpc_id: str,
    subnets: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    section(
        "NAT GATEWAY VALIDATION"
    )

    response = (
        ec2.describe_nat_gateways(
            Filter=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                }
            ]
        )
    )

    nat_gateways = [
        nat
        for nat
        in response.get(
            "NatGateways",
            [],
        )
        if nat.get("State")
        != "deleted"
    ]

    expected_count = (
        get_expected_nat_count()
    )

    if (
        len(nat_gateways)
        == expected_count
    ):
        result.passed(
            "NAT Gateway count="
            f"{expected_count} "
            "mode="
            f"{EXPECTED_NAT_GATEWAY_MODE}"
        )
    else:
        result.failed(
            "NAT Gateway count="
            f"{len(nat_gateways)} "
            f"expected={expected_count}"
        )

    public_subnet_ids = {
        subnet["SubnetId"]
        for subnet in subnets
        if get_tag(
            subnet.get("Tags"),
            "Tier",
        )
        == "public"
    }

    for nat in nat_gateways:
        nat_id = nat[
            "NatGatewayId"
        ]

        state = nat.get(
            "State"
        )

        if state == "available":
            result.passed(
                f"NAT Gateway "
                f"{nat_id} state=available"
            )
        else:
            result.failed(
                f"NAT Gateway "
                f"{nat_id} state={state} "
                "expected=available"
            )

        nat_subnet_id = nat.get(
            "SubnetId"
        )

        if (
            nat_subnet_id
            in public_subnet_ids
        ):
            result.passed(
                f"NAT Gateway "
                f"{nat_id} is in "
                "public subnet "
                f"{nat_subnet_id}"
            )
        else:
            result.failed(
                f"NAT Gateway "
                f"{nat_id} is not "
                "in a public subnet"
            )

        connectivity = nat.get(
            "ConnectivityType"
        )

        if connectivity is None:
            result.warning(
                f"NAT Gateway "
                f"{nat_id} "
                "ConnectivityType "
                "not returned by API"
            )

        elif connectivity == "public":
            result.passed(
                f"NAT Gateway "
                f"{nat_id} "
                "ConnectivityType=public"
            )

        else:
            result.failed(
                f"NAT Gateway "
                f"{nat_id} "
                "ConnectivityType="
                f"{connectivity} "
                "expected=public"
            )

        addresses = nat.get(
            "NatGatewayAddresses",
            [],
        )

        if addresses:
            result.passed(
                f"NAT Gateway "
                f"{nat_id} has "
                "gateway address"
            )
        else:
            result.warning(
                f"NAT Gateway "
                f"{nat_id} API returned "
                "no NatGatewayAddresses"
            )

    return nat_gateways


# ============================================================
# Public Routes
# ============================================================

def validate_public_routes(
    ec2,
    result: ValidationResult,
    subnets: list[dict[str, Any]],
    igw_id: str | None,
) -> None:
    section(
        "PUBLIC ROUTE VALIDATION"
    )

    public_subnets = (
        get_subnets_by_tier(
            subnets,
            "public",
        )
    )

    if not public_subnets:
        result.failed(
            "No public subnets found"
        )
        return

    if not igw_id:
        result.failed(
            "Cannot validate public "
            "routes because IGW "
            "validation failed"
        )
        return

    for subnet in public_subnets:
        subnet_id = subnet[
            "SubnetId"
        ]

        name = get_name(
            subnet.get("Tags")
        ) or subnet_id

        route_table = (
            get_subnet_route_table(
                ec2,
                subnet_id,
            )
        )

        if not route_table:
            result.failed(
                f"{name} has no "
                "explicit route table "
                "association"
            )
            continue

        route_table_id = (
            route_table[
                "RouteTableId"
            ]
        )

        result.passed(
            f"{name} associated with "
            f"{route_table_id}"
        )

        default_route = (
            get_default_route(
                route_table
            )
        )

        if not default_route:
            result.failed(
                f"{name} has no "
                "0.0.0.0/0 route"
            )
            continue

        actual_gateway_id = (
            default_route.get(
                "GatewayId"
            )
        )

        if actual_gateway_id == igw_id:
            result.passed(
                f"{name} "
                f"0.0.0.0/0 -> "
                f"{igw_id}"
            )
        else:
            result.failed(
                f"{name} "
                "0.0.0.0/0 -> "
                f"{actual_gateway_id} "
                f"expected={igw_id}"
            )

        state = default_route.get(
            "State"
        )

        if state in (
            None,
            "active",
        ):
            result.passed(
                f"{name} default "
                "route is active"
            )
        else:
            result.failed(
                f"{name} default "
                f"route state={state}"
            )


# ============================================================
# Private Application Routes
# ============================================================

def get_nat_gateway_az_map(
    nat_gateways: list[dict[str, Any]],
    subnets: list[dict[str, Any]],
) -> dict[str, str]:
    subnet_az_map = {
        subnet["SubnetId"]:
        subnet.get(
            "AvailabilityZone",
            "",
        )
        for subnet in subnets
    }

    nat_by_az: dict[
        str,
        str,
    ] = {}

    for nat in nat_gateways:
        subnet_id = nat.get(
            "SubnetId"
        )

        if not subnet_id:
            continue

        az = subnet_az_map.get(
            subnet_id
        )

        if az:
            nat_by_az[az] = (
                nat[
                    "NatGatewayId"
                ]
            )

    return nat_by_az


def validate_private_app_routes(
    ec2,
    result: ValidationResult,
    subnets: list[dict[str, Any]],
    nat_gateways: list[
        dict[str, Any]
    ],
) -> None:
    section(
        "PRIVATE APPLICATION "
        "ROUTE VALIDATION"
    )

    app_subnets = (
        get_subnets_by_tier(
            subnets,
            "private-app",
        )
    )

    if not app_subnets:
        result.failed(
            "No private-app "
            "subnets found"
        )
        return

    nat_ids = {
        nat["NatGatewayId"]
        for nat in nat_gateways
    }

    nat_by_az = (
        get_nat_gateway_az_map(
            nat_gateways,
            subnets,
        )
    )

    for subnet in app_subnets:
        subnet_id = subnet[
            "SubnetId"
        ]

        name = get_name(
            subnet.get("Tags")
        ) or subnet_id

        route_table = (
            get_subnet_route_table(
                ec2,
                subnet_id,
            )
        )

        if not route_table:
            result.failed(
                f"{name} has no "
                "explicit route table "
                "association"
            )
            continue

        result.passed(
            f"{name} associated "
            "with route table "
            f"{route_table['RouteTableId']}"
        )

        default_route = (
            get_default_route(
                route_table
            )
        )

        # NAT disabled

        if (
            EXPECTED_NAT_GATEWAY_MODE
            == "none"
        ):
            if default_route is None:
                result.passed(
                    f"{name} has no "
                    "Internet default route"
                )
            else:
                result.failed(
                    f"{name} has unexpected "
                    "0.0.0.0/0 route"
                )

            continue

        # NAT required

        if not default_route:
            result.failed(
                f"{name} has no "
                "0.0.0.0/0 route "
                "to NAT Gateway"
            )
            continue

        actual_nat_id = (
            default_route.get(
                "NatGatewayId"
            )
        )

        if not actual_nat_id:
            result.failed(
                f"{name} default route "
                "does not target a "
                "NAT Gateway"
            )
            continue

        if (
            EXPECTED_NAT_GATEWAY_MODE
            == "single"
        ):
            if actual_nat_id in nat_ids:
                result.passed(
                    f"{name} "
                    "0.0.0.0/0 -> "
                    f"{actual_nat_id}"
                )
            else:
                result.failed(
                    f"{name} "
                    "default route targets "
                    f"unknown NAT "
                    f"{actual_nat_id}"
                )

        elif (
            EXPECTED_NAT_GATEWAY_MODE
            == "one-per-az"
        ):
            az = subnet.get(
                "AvailabilityZone",
                "",
            )

            expected_nat_id = (
                nat_by_az.get(
                    az
                )
            )

            if (
                actual_nat_id
                == expected_nat_id
            ):
                result.passed(
                    f"{name} "
                    "0.0.0.0/0 -> "
                    f"{actual_nat_id} "
                    f"same AZ={az}"
                )
            else:
                result.failed(
                    f"{name} "
                    "0.0.0.0/0 -> "
                    f"{actual_nat_id} "
                    "expected="
                    f"{expected_nat_id} "
                    f"AZ={az}"
                )


# ============================================================
# Private Database Routes
# ============================================================

def validate_private_db_routes(
    ec2,
    result: ValidationResult,
    subnets: list[dict[str, Any]],
) -> None:
    section(
        "PRIVATE DATABASE "
        "ROUTE VALIDATION"
    )

    db_subnets = (
        get_subnets_by_tier(
            subnets,
            "private-db",
        )
    )

    if not db_subnets:
        result.failed(
            "No private-db "
            "subnets found"
        )
        return

    for subnet in db_subnets:
        subnet_id = subnet[
            "SubnetId"
        ]

        name = get_name(
            subnet.get("Tags")
        ) or subnet_id

        route_table = (
            get_subnet_route_table(
                ec2,
                subnet_id,
            )
        )

        if not route_table:
            result.failed(
                f"{name} has no "
                "explicit route table "
                "association"
            )
            continue

        result.passed(
            f"{name} associated "
            "with route table "
            f"{route_table['RouteTableId']}"
        )

        default_route = (
            get_default_route(
                route_table
            )
        )

        if default_route is None:
            result.passed(
                f"{name} has no "
                "Internet default route"
            )
            continue

        target = (
            default_route.get(
                "GatewayId"
            )
            or default_route.get(
                "NatGatewayId"
            )
            or default_route.get(
                "TransitGatewayId"
            )
            or default_route.get(
                "NetworkInterfaceId"
            )
            or "unknown"
        )

        result.failed(
            f"{name} has unexpected "
            f"0.0.0.0/0 -> {target}"
        )


# ============================================================
# S3 Gateway Endpoint
# ============================================================

def validate_s3_endpoint(
    ec2,
    result: ValidationResult,
    vpc_id: str,
    subnets: list[dict[str, Any]],
) -> None:
    section(
        "S3 VPC ENDPOINT VALIDATION"
    )

    if not REQUIRE_S3_ENDPOINT:
        result.warning(
            "S3 VPC Endpoint "
            "validation disabled"
        )
        return

    service_name = (
        f"com.amazonaws."
        f"{AWS_REGION}.s3"
    )

    response = (
        ec2.describe_vpc_endpoints(
            Filters=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                },
                {
                    "Name":
                    "service-name",
                    "Values": [
                        service_name
                    ],
                },
            ]
        )
    )

    endpoints = response.get(
        "VpcEndpoints",
        [],
    )

    if len(endpoints) != 1:
        result.failed(
            "S3 VPC Endpoint count="
            f"{len(endpoints)} "
            "expected=1"
        )
        return

    endpoint = endpoints[0]

    endpoint_id = endpoint[
        "VpcEndpointId"
    ]

    result.passed(
        f"S3 VPC Endpoint exists: "
        f"{endpoint_id}"
    )

    # Type

    endpoint_type = endpoint.get(
        "VpcEndpointType"
    )

    if endpoint_type == "Gateway":
        result.passed(
            "S3 VPC Endpoint "
            "type=Gateway"
        )
    else:
        result.failed(
            "S3 VPC Endpoint "
            f"type={endpoint_type} "
            "expected=Gateway"
        )

    # State

    endpoint_state = endpoint.get(
        "State"
    )

    if endpoint_state == "available":
        result.passed(
            "S3 VPC Endpoint "
            "state=available"
        )
    else:
        result.failed(
            "S3 VPC Endpoint "
            f"state={endpoint_state} "
            "expected=available"
        )

    # Expected private RTs

    expected_route_table_ids: set[
        str
    ] = set()

    for tier in (
        "private-app",
        "private-db",
    ):
        tier_subnets = (
            get_subnets_by_tier(
                subnets,
                tier,
            )
        )

        for subnet in tier_subnets:
            route_table = (
                get_subnet_route_table(
                    ec2,
                    subnet["SubnetId"],
                )
            )

            if route_table:
                expected_route_table_ids.add(
                    route_table[
                        "RouteTableId"
                    ]
                )

    actual_route_table_ids = set(
        endpoint.get(
            "RouteTableIds",
            [],
        )
    )

    missing_route_tables = (
        expected_route_table_ids
        - actual_route_table_ids
    )

    if not missing_route_tables:
        result.passed(
            "S3 Gateway Endpoint "
            "includes all private "
            "app and DB route tables"
        )
    else:
        result.failed(
            "S3 Gateway Endpoint "
            "missing private route "
            "tables: "
            f"{sorted(missing_route_tables)}"
        )

    # Public Route Tables

    public_route_table_ids: set[
        str
    ] = set()

    for subnet in (
        get_subnets_by_tier(
            subnets,
            "public",
        )
    ):
        route_table = (
            get_subnet_route_table(
                ec2,
                subnet["SubnetId"],
            )
        )

        if route_table:
            public_route_table_ids.add(
                route_table[
                    "RouteTableId"
                ]
            )

    unexpected_public = (
        actual_route_table_ids
        & public_route_table_ids
    )

    if unexpected_public:
        result.failed(
            "S3 Gateway Endpoint "
            "unexpectedly associated "
            "with public route table: "
            f"{sorted(unexpected_public)}"
        )
    else:
        result.passed(
            "S3 Gateway Endpoint "
            "is not associated with "
            "public route tables"
        )


# ============================================================
# Optional Network ACL
# ============================================================

def validate_network_acls(
    ec2,
    result: ValidationResult,
    vpc_id: str,
    subnets: list[dict[str, Any]],
) -> None:
    section(
        "NETWORK ACL VALIDATION"
    )

    if not REQUIRE_CUSTOM_NACLS:
        result.warning(
            "Custom NACL validation "
            "disabled"
        )
        return

    response = (
        ec2.describe_network_acls(
            Filters=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                }
            ]
        )
    )

    network_acls = response.get(
        "NetworkAcls",
        [],
    )

    custom_nacls = [
        nacl
        for nacl in network_acls
        if not nacl.get(
            "IsDefault",
            False,
        )
    ]

    expected_tiers = {
        "public",
        "private-app",
        "private-db",
    }

    for tier in expected_tiers:
        tier_nacls = [
            nacl
            for nacl in custom_nacls
            if get_tag(
                nacl.get("Tags"),
                "Tier",
            )
            == tier
        ]

        if len(tier_nacls) != 1:
            result.failed(
                f"Custom NACL tier="
                f"{tier} count="
                f"{len(tier_nacls)} "
                "expected=1"
            )
            continue

        nacl = tier_nacls[0]

        result.passed(
            f"Custom NACL exists "
            f"for tier={tier}: "
            f"{nacl['NetworkAclId']}"
        )

        expected_subnet_ids = {
            subnet["SubnetId"]
            for subnet in subnets
            if get_tag(
                subnet.get("Tags"),
                "Tier",
            )
            == tier
        }

        actual_subnet_ids = {
            association[
                "SubnetId"
            ]
            for association
            in nacl.get(
                "Associations",
                [],
            )
            if association.get(
                "SubnetId"
            )
        }

        if (
            actual_subnet_ids
            == expected_subnet_ids
        ):
            result.passed(
                f"NACL tier={tier} "
                "subnet associations "
                "are correct"
            )
        else:
            result.failed(
                f"NACL tier={tier} "
                "subnet associations "
                "are incorrect"
            )


# ============================================================
# Optional VPC Flow Logs
# ============================================================

def validate_flow_logs(
    ec2,
    result: ValidationResult,
    vpc_id: str,
) -> None:
    section(
        "VPC FLOW LOG VALIDATION"
    )

    if not REQUIRE_FLOW_LOGS:
        result.warning(
            "VPC Flow Log validation "
            "disabled"
        )
        return

    response = (
        ec2.describe_flow_logs(
            Filter=[
                {
                    "Name":
                    "resource-id",
                    "Values": [vpc_id],
                }
            ]
        )
    )

    flow_logs = response.get(
        "FlowLogs",
        [],
    )

    if not flow_logs:
        result.failed(
            "No VPC Flow Logs found"
        )
        return

    result.passed(
        "VPC Flow Log count="
        f"{len(flow_logs)}"
    )

    for flow_log in flow_logs:
        flow_log_id = flow_log.get(
            "FlowLogId",
            "-",
        )

        traffic_type = (
            flow_log.get(
                "TrafficType"
            )
        )

        if traffic_type == "ALL":
            result.passed(
                f"Flow Log "
                f"{flow_log_id} "
                "TrafficType=ALL"
            )
        else:
            result.failed(
                f"Flow Log "
                f"{flow_log_id} "
                "TrafficType="
                f"{traffic_type} "
                "expected=ALL"
            )

        status = flow_log.get(
            "FlowLogStatus"
        )

        if status is None:
            result.warning(
                f"Flow Log "
                f"{flow_log_id} "
                "status not returned"
            )

        elif status.upper() == "ACTIVE":
            result.passed(
                f"Flow Log "
                f"{flow_log_id} "
                "status=ACTIVE"
            )

        else:
            result.failed(
                f"Flow Log "
                f"{flow_log_id} "
                f"status={status} "
                "expected=ACTIVE"
            )


# ============================================================
# Main Network Validation
# ============================================================

def validate_network() -> ValidationResult:
    result = ValidationResult()

    section(
        "NETWORK VALIDATION START"
    )

    print(
        f"[INFO] Project="
        f"{PROJECT_NAME}"
    )

    print(
        f"[INFO] Environment="
        f"{ENVIRONMENT}"
    )

    print(
        f"[INFO] Region="
        f"{AWS_REGION}"
    )

    print(
        f"[INFO] NAT Mode="
        f"{EXPECTED_NAT_GATEWAY_MODE}"
    )

    # Validate configuration first

    get_expected_nat_count()

    # EC2 Client

    ec2 = get_ec2_client()

    # Connectivity test

    ec2.describe_vpcs()

    result.passed(
        "EC2 API connection successful"
    )

    # VPC

    vpc = validate_vpc(
        ec2,
        result,
    )

    if not vpc:
        return result

    vpc_id = vpc[
        "VpcId"
    ]

    # Subnets

    subnets = validate_subnets(
        ec2,
        result,
        vpc_id,
    )

    # IGW

    igw_id = (
        validate_internet_gateway(
            ec2,
            result,
            vpc_id,
        )
    )

    # NAT Gateway

    nat_gateways = (
        validate_nat_gateways(
            ec2,
            result,
            vpc_id,
            subnets,
        )
    )

    # Public Route

    validate_public_routes(
        ec2,
        result,
        subnets,
        igw_id,
    )

    # Private App Route

    validate_private_app_routes(
        ec2,
        result,
        subnets,
        nat_gateways,
    )

    # Private DB Route

    validate_private_db_routes(
        ec2,
        result,
        subnets,
    )

    # S3 Endpoint

    validate_s3_endpoint(
        ec2,
        result,
        vpc_id,
        subnets,
    )

    # Optional NACL

    validate_network_acls(
        ec2,
        result,
        vpc_id,
        subnets,
    )

    # Optional Flow Logs

    validate_flow_logs(
        ec2,
        result,
        vpc_id,
    )

    return result


# ============================================================
# Summary
# ============================================================

def print_summary(
    result: ValidationResult,
) -> int:
    section(
        "VALIDATION SUMMARY"
    )

    print(
        f"PASS : {result.pass_count}"
    )

    print(
        f"WARN : {result.warn_count}"
    )

    print(
        f"FAIL : {result.fail_count}"
    )

    print()

    if result.success:
        print(
            "[SUCCESS] "
            "Network validation passed."
        )
        return 0

    print(
        "[FAILED] "
        "Network validation failed."
    )

    return 1


# ============================================================
# Entry Point
# ============================================================

def main() -> None:
    try:
        result = (
            validate_network()
        )

        exit_code = (
            print_summary(
                result
            )
        )

        sys.exit(
            exit_code
        )

    except EndpointConnectionError as exc:
        print(
            "\n[ERROR] Unable to "
            "connect to LocalStack/"
            "AWS endpoint:"
        )
        print(exc)

        sys.exit(2)

    except ClientError as exc:
        error = exc.response.get(
            "Error",
            {},
        )

        print(
            "\n[ERROR] AWS API "
            "request failed"
        )

        print(
            "Code="
            f"{error.get('Code', '-')}"
        )

        print(
            "Message="
            f"{error.get('Message', '-')}"
        )

        sys.exit(2)

    except BotoCoreError as exc:
        print(
            "\n[ERROR] "
            "Boto3/Botocore error: "
            f"{exc}"
        )

        sys.exit(2)

    except ValueError as exc:
        print(
            "\n[ERROR] Invalid "
            f"configuration: {exc}"
        )

        sys.exit(2)

    except Exception as exc:
        print(
            "\n[ERROR] Unexpected "
            f"{type(exc).__name__}: "
            f"{exc}"
        )

        sys.exit(2)


if __name__ == "__main__":
    main()