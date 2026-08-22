import os
import sys

from botocore.exceptions import (
    BotoCoreError,
    ClientError,
    EndpointConnectionError,
)

from common.aws_clients import get_ec2_client
from common.config import Config


# ============================================================
# Expected Configuration
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
)

REQUIRE_S3_ENDPOINT = (
    os.getenv(
        "REQUIRE_S3_ENDPOINT",
        "true",
    ).lower()
    == "true"
)

REQUIRE_CUSTOM_NACLS = (
    os.getenv(
        "REQUIRE_CUSTOM_NACLS",
        "false",
    ).lower()
    == "true"
)

REQUIRE_FLOW_LOGS = (
    os.getenv(
        "REQUIRE_FLOW_LOGS",
        "false",
    ).lower()
    == "true"
)


# ============================================================
# Validation Result
# ============================================================

class ValidationResult:
    def __init__(self):
        self.pass_count = 0
        self.fail_count = 0
        self.warn_count = 0

    def passed(self, message):
        print(f"[PASS] {message}")
        self.pass_count += 1

    def failed(self, message):
        print(f"[FAIL] {message}")
        self.fail_count += 1

    def warning(self, message):
        print(f"[WARN] {message}")
        self.warn_count += 1

    @property
    def success(self):
        return self.fail_count == 0


# ============================================================
# Generic Helpers
# ============================================================

def section(title):
    print()
    print("=" * 72)
    print(title)
    print("=" * 72)


def get_tag(tags, key, default=None):
    if not tags:
        return default

    for tag in tags:
        if tag.get("Key") == key:
            return tag.get(
                "Value",
                default,
            )

    return default


def get_name(tags):
    return get_tag(
        tags,
        "Name",
    )


def get_project_prefix():
    return (
        f"{Config.PROJECT_NAME}-"
        f"{Config.ENVIRONMENT}"
    )


def get_expected_vpc_name():
    return (
        f"{get_project_prefix()}-vpc"
    )


def get_short_name(resource_name):
    if not resource_name:
        return None

    prefix = (
        f"{get_project_prefix()}-"
    )

    if not resource_name.startswith(prefix):
        return resource_name

    return resource_name[len(prefix):]


def get_default_route(route_table):
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
    subnet_id,
):
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
    subnets,
    tier,
):
    result = []

    for subnet in subnets:
        if (
            get_tag(
                subnet.get("Tags"),
                "Tier",
            )
            == tier
        ):
            result.append(subnet)

    return result


# ============================================================
# VPC Discovery
# ============================================================

def find_project_vpc(ec2):
    response = ec2.describe_vpcs()

    expected_name = (
        get_expected_vpc_name()
    )

    matches = []

    for vpc in response.get(
        "Vpcs",
        [],
    ):
        if (
            get_name(vpc.get("Tags"))
            == expected_name
        ):
            matches.append(vpc)

    if len(matches) != 1:
        return None

    return matches[0]


# ============================================================
# VPC Validation
# ============================================================

def validate_vpc(
    ec2,
    result,
):
    section("VPC VALIDATION")

    vpc = find_project_vpc(ec2)

    if not vpc:
        result.failed(
            f"Exactly one project VPC must exist: "
            f"{get_expected_vpc_name()}"
        )
        return None

    vpc_id = vpc["VpcId"]

    result.passed(
        f"Project VPC found: {vpc_id}"
    )

    if (
        vpc.get("State")
        == "available"
    ):
        result.passed(
            "VPC state is available"
        )
    else:
        result.failed(
            f"VPC state={vpc.get('State')} "
            f"expected=available"
        )

    if (
        vpc.get("CidrBlock")
        == EXPECTED_VPC_CIDR
    ):
        result.passed(
            f"VPC CIDR={EXPECTED_VPC_CIDR}"
        )
    else:
        result.failed(
            f"VPC CIDR={vpc.get('CidrBlock')} "
            f"expected={EXPECTED_VPC_CIDR}"
        )

    # --------------------------------------------------------
    # DNS Support
    # --------------------------------------------------------

    dns_support_response = (
        ec2.describe_vpc_attribute(
            VpcId=vpc_id,
            Attribute="enableDnsSupport",
        )
    )

    dns_support = (
        dns_support_response
        .get(
            "EnableDnsSupport",
            {},
        )
        .get(
            "Value",
            False,
        )
    )

    if dns_support:
        result.passed(
            "VPC DNS support is enabled"
        )
    else:
        result.failed(
            "VPC DNS support is disabled"
        )

    # --------------------------------------------------------
    # DNS Hostnames
    # --------------------------------------------------------

    dns_hostnames_response = (
        ec2.describe_vpc_attribute(
            VpcId=vpc_id,
            Attribute="enableDnsHostnames",
        )
    )

    dns_hostnames = (
        dns_hostnames_response
        .get(
            "EnableDnsHostnames",
            {},
        )
        .get(
            "Value",
            False,
        )
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
# Subnet Validation
# ============================================================

def validate_subnets(
    ec2,
    result,
    vpc_id,
):
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

    # --------------------------------------------------------
    # Exact Count
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # Build Name Map
    # --------------------------------------------------------

    actual = {}

    for subnet in subnets:
        full_name = get_name(
            subnet.get("Tags")
        )

        if not full_name:
            continue

        short_name = get_short_name(
            full_name
        )

        actual[short_name] = subnet

    # --------------------------------------------------------
    # Validate Expected Subnets
    # --------------------------------------------------------

    for name, expected in (
        EXPECTED_SUBNETS.items()
    ):
        subnet = actual.get(name)

        if not subnet:
            result.failed(
                f"Subnet missing: {name}"
            )
            continue

        subnet_id = subnet["SubnetId"]

        result.passed(
            f"Subnet exists: "
            f"{name} ({subnet_id})"
        )

        # CIDR

        if (
            subnet.get("CidrBlock")
            == expected["cidr"]
        ):
            result.passed(
                f"{name} CIDR="
                f"{expected['cidr']}"
            )
        else:
            result.failed(
                f"{name} CIDR="
                f"{subnet.get('CidrBlock')} "
                f"expected={expected['cidr']}"
            )

        # AZ

        if (
            subnet.get(
                "AvailabilityZone"
            )
            == expected["az"]
        ):
            result.passed(
                f"{name} AZ="
                f"{expected['az']}"
            )
        else:
            result.failed(
                f"{name} AZ="
                f"{subnet.get('AvailabilityZone')} "
                f"expected={expected['az']}"
            )

        # Public IP

        public_ip = subnet.get(
            "MapPublicIpOnLaunch",
            False,
        )

        if (
            public_ip
            == expected["public"]
        ):
            result.passed(
                f"{name} "
                f"MapPublicIpOnLaunch="
                f"{expected['public']}"
            )
        else:
            result.failed(
                f"{name} "
                f"MapPublicIpOnLaunch="
                f"{public_ip} "
                f"expected="
                f"{expected['public']}"
            )

        # Tier Tag

        tier = get_tag(
            subnet.get("Tags"),
            "Tier",
        )

        if (
            tier
            == expected["tier"]
        ):
            result.passed(
                f"{name} Tier="
                f"{expected['tier']}"
            )
        else:
            result.failed(
                f"{name} Tier="
                f"{tier} "
                f"expected="
                f"{expected['tier']}"
            )

    return subnets


# ============================================================
# Internet Gateway Validation
# ============================================================

def validate_internet_gateway(
    ec2,
    result,
    vpc_id,
):
    section(
        "INTERNET GATEWAY VALIDATION"
    )

    response = (
        ec2.describe_internet_gateways(
            Filters=[
                {
                    "Name": "attachment.vpc-id",
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
            "Expected exactly 1 "
            f"Internet Gateway, "
            f"found {len(gateways)}"
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

    attachments = gateway.get(
        "Attachments",
        [],
    )

    matching_attachment = None

    for attachment in attachments:
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

    state = matching_attachment.get(
        "State"
    )

    if state == "available":
        result.passed(
            "Internet Gateway "
            "attachment is available"
        )
    else:
        result.failed(
            f"Internet Gateway "
            f"attachment state={state} "
            f"expected=available"
        )

    return igw_id


# ============================================================
# NAT Gateway Validation
# ============================================================

def get_expected_nat_count():
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
            subnet["az"]
            for subnet
            in EXPECTED_SUBNETS.values()
            if (
                subnet["tier"]
                == "public"
            )
        }

        return len(public_azs)

    raise ValueError(
        "NAT_GATEWAY_MODE must be "
        "none, single, or one-per-az"
    )


def validate_nat_gateways(
    ec2,
    result,
    vpc_id,
    subnets,
):
    section(
        "NAT GATEWAY VALIDATION"
    )

    response = ec2.describe_nat_gateways(
        Filter=[
            {
                "Name": "vpc-id",
                "Values": [vpc_id],
            }
        ]
    )

    nat_gateways = [
        nat
        for nat
        in response.get(
            "NatGateways",
            [],
        )
        if (
            nat.get("State")
            != "deleted"
        )
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
            f"mode="
            f"{EXPECTED_NAT_GATEWAY_MODE}"
        )
    else:
        result.failed(
            f"NAT Gateway count="
            f"{len(nat_gateways)} "
            f"expected={expected_count} "
            f"mode="
            f"{EXPECTED_NAT_GATEWAY_MODE}"
        )

    if expected_count == 0:
        return nat_gateways

    public_subnet_ids = {
        subnet["SubnetId"]
        for subnet in subnets
        if (
            get_tag(
                subnet.get("Tags"),
                "Tier",
            )
            == "public"
        )
    }

    for nat in nat_gateways:
        nat_id = nat[
            "NatGatewayId"
        ]

        # State

        if (
            nat.get("State")
            == "available"
        ):
            result.passed(
                f"NAT Gateway "
                f"{nat_id} is available"
            )
        else:
            result.failed(
                f"NAT Gateway "
                f"{nat_id} state="
                f"{nat.get('State')} "
                f"expected=available"
            )

        # Public subnet

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
                f"public subnet "
                f"{nat_subnet_id}"
            )
        else:
            result.failed(
                f"NAT Gateway "
                f"{nat_id} is not "
                "located in an expected "
                "public subnet"
            )

        # Connectivity Type

        connectivity = nat.get(
            "ConnectivityType"
        )

        if connectivity:
            if connectivity == "public":
                result.passed(
                    f"NAT Gateway "
                    f"{nat_id} "
                    "connectivity=public"
                )
            else:
                result.failed(
                    f"NAT Gateway "
                    f"{nat_id} "
                    f"connectivity="
                    f"{connectivity} "
                    f"expected=public"
                )

        # NAT Address

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
                f"{nat_id} has no "
                "NatGatewayAddresses "
                "in API response"
            )

    return nat_gateways


# ============================================================
# Public Route Validation
# ============================================================

def validate_public_routes(
    ec2,
    result,
    subnets,
    igw_id,
):
    section(
        "PUBLIC ROUTE VALIDATION"
    )

    public_subnets = (
        get_subnets_by_tier(
            subnets,
            "public",
        )
    )

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
        )

        route_table = (
            get_subnet_route_table(
                ec2,
                subnet_id,
            )
        )

        if not route_table:
            result.failed(
                f"{name} has no explicit "
                "route table association"
            )
            continue

        route_table_id = (
            route_table[
                "RouteTableId"
            ]
        )

        result.passed(
            f"{name} associated with "
            f"route table "
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

        gateway_id = (
            default_route.get(
                "GatewayId"
            )
        )

        if gateway_id == igw_id:
            result.passed(
                f"{name} "
                f"0.0.0.0/0 -> "
                f"{igw_id}"
            )
        else:
            result.failed(
                f"{name} "
                f"0.0.0.0/0 -> "
                f"{gateway_id} "
                f"expected={igw_id}"
            )

        route_state = (
            default_route.get(
                "State"
            )
        )

        if (
            route_state
            in (
                None,
                "active",
            )
        ):
            result.passed(
                f"{name} default "
                "route is active"
            )
        else:
            result.failed(
                f"{name} default "
                f"route state="
                f"{route_state}"
            )


# ============================================================
# Private Application Route Validation
# ============================================================

def get_nat_gateway_az_map(
    nat_gateways,
    subnets,
):
    subnet_az = {
        subnet["SubnetId"]:
        subnet.get(
            "AvailabilityZone"
        )
        for subnet in subnets
    }

    nat_by_az = {}

    for nat in nat_gateways:
        subnet_id = nat.get(
            "SubnetId"
        )

        az = subnet_az.get(
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
    result,
    subnets,
    nat_gateways,
):
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
        )

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
            f"{name} associated "
            f"with route table "
            f"{route_table_id}"
        )

        default_route = (
            get_default_route(
                route_table
            )
        )

        # ----------------------------------------------------
        # NAT Mode = none
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # NAT Required
        # ----------------------------------------------------

        if not default_route:
            result.failed(
                f"{name} has no "
                "0.0.0.0/0 route "
                "to NAT Gateway"
            )
            continue

        nat_gateway_id = (
            default_route.get(
                "NatGatewayId"
            )
        )

        if not nat_gateway_id:
            result.failed(
                f"{name} default route "
                "does not target a "
                "NAT Gateway"
            )
            continue

        # ----------------------------------------------------
        # Single NAT
        # ----------------------------------------------------

        if (
            EXPECTED_NAT_GATEWAY_MODE
            == "single"
        ):
            if (
                nat_gateway_id
                in nat_ids
            ):
                result.passed(
                    f"{name} "
                    f"0.0.0.0/0 -> "
                    f"{nat_gateway_id}"
                )
            else:
                result.failed(
                    f"{name} default route "
                    f"targets unknown NAT "
                    f"{nat_gateway_id}"
                )

        # ----------------------------------------------------
        # NAT Per AZ
        # ----------------------------------------------------

        elif (
            EXPECTED_NAT_GATEWAY_MODE
            == "one-per-az"
        ):
            az = subnet.get(
                "AvailabilityZone"
            )

            expected_nat_id = (
                nat_by_az.get(az)
            )

            if (
                nat_gateway_id
                == expected_nat_id
            ):
                result.passed(
                    f"{name} "
                    f"0.0.0.0/0 -> "
                    f"{nat_gateway_id} "
                    f"same AZ={az}"
                )
            else:
                result.failed(
                    f"{name} "
                    f"0.0.0.0/0 -> "
                    f"{nat_gateway_id} "
                    f"expected NAT="
                    f"{expected_nat_id} "
                    f"in AZ={az}"
                )


# ============================================================
# Private Database Route Validation
# ============================================================

def validate_private_db_routes(
    ec2,
    result,
    subnets,
):
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

    for subnet in db_subnets:
        subnet_id = subnet[
            "SubnetId"
        ]

        name = get_name(
            subnet.get("Tags")
        )

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
            f"{name} associated "
            f"with route table "
            f"{route_table_id}"
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
        else:
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
                or "unknown"
            )

            result.failed(
                f"{name} has unexpected "
                f"0.0.0.0/0 -> {target}"
            )


# ============================================================
# S3 Gateway Endpoint Validation
# ============================================================

def validate_s3_endpoint(
    ec2,
    result,
    vpc_id,
    subnets,
):
    section(
        "S3 VPC ENDPOINT VALIDATION"
    )

    if not REQUIRE_S3_ENDPOINT:
        result.warning(
            "S3 endpoint validation "
            "is disabled"
        )
        return

    service_name = (
        f"com.amazonaws."
        f"{Config.AWS_REGION}.s3"
    )

    response = (
        ec2.describe_vpc_endpoints(
            Filters=[
                {
                    "Name": "vpc-id",
                    "Values": [vpc_id],
                },
                {
                    "Name": "service-name",
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
            f"Expected exactly 1 "
            f"S3 VPC Endpoint, "
            f"found {len(endpoints)}"
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

    # --------------------------------------------------------
    # Type
    # --------------------------------------------------------

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
            f"S3 VPC Endpoint "
            f"type={endpoint_type} "
            f"expected=Gateway"
        )

    # --------------------------------------------------------
    # State
    # --------------------------------------------------------

    endpoint_state = endpoint.get(
        "State"
    )

    if endpoint_state in (
        "available",
        "pending",
    ):
        result.passed(
            f"S3 VPC Endpoint "
            f"state={endpoint_state}"
        )
    else:
        result.failed(
            f"S3 VPC Endpoint "
            f"state={endpoint_state}"
        )

    # --------------------------------------------------------
    # Expected Route Tables
    # --------------------------------------------------------

    expected_route_table_ids = set()

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
            "is attached to all "
            "private app and DB "
            "route tables"
        )
    else:
        result.failed(
            "S3 Gateway Endpoint "
            "missing route tables: "
            f"{sorted(missing_route_tables)}"
        )

    # Public RT should not be required

    public_route_table_ids = set()

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
        result.warning(
            "S3 Gateway Endpoint is "
            "also associated with "
            "public route table(s): "
            f"{sorted(unexpected_public)}"
        )
    else:
        result.passed(
            "S3 Gateway Endpoint "
            "is not associated with "
            "public route tables"
        )


# ============================================================
# Optional Custom NACL Validation
# ============================================================

def validate_network_acls(
    ec2,
    result,
    vpc_id,
    subnets,
):
    section(
        "NETWORK ACL VALIDATION"
    )

    if not REQUIRE_CUSTOM_NACLS:
        result.warning(
            "Custom Network ACL "
            "validation is disabled"
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

    nacls_by_tier = {}

    for nacl in custom_nacls:
        tier = get_tag(
            nacl.get("Tags"),
            "Tier",
        )

        if tier:
            nacls_by_tier.setdefault(
                tier,
                [],
            ).append(nacl)

    for tier in expected_tiers:
        tier_nacls = (
            nacls_by_tier.get(
                tier,
                [],
            )
        )

        if len(tier_nacls) != 1:
            result.failed(
                f"Expected exactly "
                f"1 custom NACL for "
                f"tier={tier}, "
                f"found "
                f"{len(tier_nacls)}"
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
            if (
                get_tag(
                    subnet.get("Tags"),
                    "Tier",
                )
                == tier
            )
        }

        actual_subnet_ids = {
            association.get(
                "SubnetId"
            )
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
            expected_subnet_ids
            == actual_subnet_ids
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
                "do not match expected "
                "subnets"
            )


# ============================================================
# Optional Flow Log Validation
# ============================================================

def validate_flow_logs(
    ec2,
    result,
    vpc_id,
):
    section(
        "VPC FLOW LOG VALIDATION"
    )

    if not REQUIRE_FLOW_LOGS:
        result.warning(
            "VPC Flow Log validation "
            "is disabled"
        )
        return

    response = ec2.describe_flow_logs(
        Filter=[
            {
                "Name": "resource-id",
                "Values": [vpc_id],
            }
        ]
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
        f"VPC Flow Log count="
        f"{len(flow_logs)}"
    )

    for flow_log in flow_logs:
        flow_log_id = (
            flow_log.get(
                "FlowLogId",
                "-",
            )
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
                f"TrafficType="
                f"{traffic_type} "
                f"expected=ALL"
            )

        status = flow_log.get(
            "FlowLogStatus"
        )

        if status:
            if status in (
                "ACTIVE",
                "active",
            ):
                result.passed(
                    f"Flow Log "
                    f"{flow_log_id} "
                    f"status={status}"
                )
            else:
                result.failed(
                    f"Flow Log "
                    f"{flow_log_id} "
                    f"status={status}"
                )


# ============================================================
# Network Validation
# ============================================================

def validate_network():
    result = ValidationResult()

    ec2 = get_ec2_client()

    section(
        "NETWORK VALIDATION START"
    )

    print(
        f"[INFO] Project="
        f"{Config.PROJECT_NAME}"
    )

    print(
        f"[INFO] Environment="
        f"{Config.ENVIRONMENT}"
    )

    print(
        f"[INFO] Region="
        f"{Config.AWS_REGION}"
    )

    print(
        f"[INFO] NAT Mode="
        f"{EXPECTED_NAT_GATEWAY_MODE}"
    )

    # --------------------------------------------------------
    # Connectivity
    # --------------------------------------------------------

    ec2.describe_vpcs(
        MaxResults=5
    )

    result.passed(
        "EC2 API connection successful"
    )

    # --------------------------------------------------------
    # VPC
    # --------------------------------------------------------

    vpc = validate_vpc(
        ec2,
        result,
    )

    if not vpc:
        return result

    vpc_id = vpc[
        "VpcId"
    ]

    # --------------------------------------------------------
    # Subnets
    # --------------------------------------------------------

    subnets = validate_subnets(
        ec2,
        result,
        vpc_id,
    )

    # --------------------------------------------------------
    # Internet Gateway
    # --------------------------------------------------------

    igw_id = (
        validate_internet_gateway(
            ec2,
            result,
            vpc_id,
        )
    )

    # --------------------------------------------------------
    # NAT Gateway
    # --------------------------------------------------------

    nat_gateways = (
        validate_nat_gateways(
            ec2,
            result,
            vpc_id,
            subnets,
        )
    )

    # --------------------------------------------------------
    # Routes
    # --------------------------------------------------------

    validate_public_routes(
        ec2,
        result,
        subnets,
        igw_id,
    )

    validate_private_app_routes(
        ec2,
        result,
        subnets,
        nat_gateways,
    )

    validate_private_db_routes(
        ec2,
        result,
        subnets,
    )

    # --------------------------------------------------------
    # S3 VPC Endpoint
    # --------------------------------------------------------

    validate_s3_endpoint(
        ec2,
        result,
        vpc_id,
        subnets,
    )

    # --------------------------------------------------------
    # Optional Controls
    # --------------------------------------------------------

    validate_network_acls(
        ec2,
        result,
        vpc_id,
        subnets,
    )

    validate_flow_logs(
        ec2,
        result,
        vpc_id,
    )

    return result


# ============================================================
# Summary
# ============================================================

def print_summary(result):
    section(
        "VALIDATION SUMMARY"
    )

    print(
        f"PASS : "
        f"{result.pass_count}"
    )

    print(
        f"WARN : "
        f"{result.warn_count}"
    )

    print(
        f"FAIL : "
        f"{result.fail_count}"
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
# Main
# ============================================================

def main():
    try:
        result = validate_network()

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
            "\n[ERROR] Unable to connect "
            "to LocalStack/AWS endpoint:"
        )
        print(exc)

        sys.exit(2)

    except ClientError as exc:
        error = exc.response.get(
            "Error",
            {},
        )

        print(
            "\n[ERROR] AWS API request "
            "failed:"
        )

        print(
            f"Code="
            f"{error.get('Code', '-')}"
        )

        print(
            f"Message="
            f"{error.get('Message', '-')}"
        )

        sys.exit(2)

    except BotoCoreError as exc:
        print(
            "\n[ERROR] Boto3/Botocore "
            f"error: {exc}"
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