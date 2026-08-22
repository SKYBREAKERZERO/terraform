import sys
from typing import Any

from botocore.exceptions import BotoCoreError, ClientError, EndpointConnectionError

from common.aws_clients import get_ec2_client


# ============================================================
# Generic Helpers
# ============================================================

def get_tag(tags: list[dict[str, str]] | None, key: str, default: str = "-") -> str:
    if not tags:
        return default

    for tag in tags:
        if tag.get("Key") == key:
            return tag.get("Value", default)

    return default


def get_name(tags: list[dict[str, str]] | None) -> str:
    return get_tag(tags, "Name")


def section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def print_count(resource_name: str, resources: list[Any]) -> None:
    print(f"Count={len(resources)}")

    if not resources:
        print(f"No {resource_name} found.")


def safe_value(value: Any, default: str = "-") -> str:
    if value is None or value == "":
        return default

    return str(value)


# ============================================================
# VPC
# ============================================================

def show_vpcs(ec2) -> None:
    section("VPC")

    response = ec2.describe_vpcs()
    vpcs = response.get("Vpcs", [])

    print_count("VPCs", vpcs)

    for vpc in vpcs:
        print(
            f"Name={get_name(vpc.get('Tags'))} "
            f"VPC_ID={vpc.get('VpcId', '-')} "
            f"CIDR={vpc.get('CidrBlock', '-')} "
            f"State={vpc.get('State', '-')} "
            f"Default={vpc.get('IsDefault', False)}"
        )


# ============================================================
# Subnets
# ============================================================

def show_subnets(ec2) -> None:
    section("SUBNETS")

    response = ec2.describe_subnets()
    subnets = response.get("Subnets", [])

    print_count("subnets", subnets)

    subnets = sorted(
        subnets,
        key=lambda subnet: (
            get_tag(subnet.get("Tags"), "Tier"),
            subnet.get("AvailabilityZone", ""),
            subnet.get("CidrBlock", ""),
        ),
    )

    for subnet in subnets:
        print(
            f"Name={get_name(subnet.get('Tags'))} "
            f"Tier={get_tag(subnet.get('Tags'), 'Tier')} "
            f"Subnet_ID={subnet.get('SubnetId', '-')} "
            f"VPC_ID={subnet.get('VpcId', '-')} "
            f"CIDR={subnet.get('CidrBlock', '-')} "
            f"AZ={subnet.get('AvailabilityZone', '-')} "
            f"Public_IP={subnet.get('MapPublicIpOnLaunch', False)}"
        )


# ============================================================
# Internet Gateways
# ============================================================

def show_internet_gateways(ec2) -> None:
    section("INTERNET GATEWAYS")

    response = ec2.describe_internet_gateways()
    gateways = response.get("InternetGateways", [])

    print_count("Internet Gateways", gateways)

    for igw in gateways:
        attachments = igw.get("Attachments", [])

        if not attachments:
            print(
                f"Name={get_name(igw.get('Tags'))} "
                f"IGW_ID={igw.get('InternetGatewayId', '-')} "
                f"VPC=- "
                f"State=detached"
            )
            continue

        for attachment in attachments:
            print(
                f"Name={get_name(igw.get('Tags'))} "
                f"IGW_ID={igw.get('InternetGatewayId', '-')} "
                f"VPC={attachment.get('VpcId', '-')} "
                f"State={attachment.get('State', '-')}"
            )


# ============================================================
# Elastic IPs
# ============================================================

def show_elastic_ips(ec2) -> None:
    section("ELASTIC IPS")

    response = ec2.describe_addresses()
    addresses = response.get("Addresses", [])

    print_count("Elastic IPs", addresses)

    for address in addresses:
        print(
            f"Name={get_name(address.get('Tags'))} "
            f"Allocation_ID={address.get('AllocationId', '-')} "
            f"Public_IP={address.get('PublicIp', '-')} "
            f"Private_IP={address.get('PrivateIpAddress', '-')} "
            f"Domain={address.get('Domain', '-')} "
            f"Network_Interface={address.get('NetworkInterfaceId', '-')}"
        )


# ============================================================
# NAT Gateways
# ============================================================

def show_nat_gateways(ec2) -> None:
    section("NAT GATEWAYS")

    response = ec2.describe_nat_gateways()
    nat_gateways = response.get("NatGateways", [])

    print_count("NAT Gateways", nat_gateways)

    for nat in nat_gateways:
        addresses = nat.get("NatGatewayAddresses", [])

        public_ips = [
            address.get("PublicIp")
            for address in addresses
            if address.get("PublicIp")
        ]

        private_ips = [
            address.get("PrivateIp")
            for address in addresses
            if address.get("PrivateIp")
        ]

        print(
            f"Name={get_name(nat.get('Tags'))} "
            f"NAT_ID={nat.get('NatGatewayId', '-')} "
            f"VPC_ID={nat.get('VpcId', '-')} "
            f"Subnet_ID={nat.get('SubnetId', '-')} "
            f"State={nat.get('State', '-')} "
            f"Connectivity={nat.get('ConnectivityType', '-')} "
            f"Public_IP={','.join(public_ips) if public_ips else '-'} "
            f"Private_IP={','.join(private_ips) if private_ips else '-'}"
        )


# ============================================================
# Route Tables
# ============================================================

def get_route_destination(route: dict[str, Any]) -> str:
    return (
        route.get("DestinationCidrBlock")
        or route.get("DestinationIpv6CidrBlock")
        or route.get("DestinationPrefixListId")
        or "-"
    )


def get_route_target(route: dict[str, Any]) -> str:
    possible_targets = [
        ("Gateway", route.get("GatewayId")),
        ("NAT", route.get("NatGatewayId")),
        ("TransitGateway", route.get("TransitGatewayId")),
        ("Peering", route.get("VpcPeeringConnectionId")),
        ("NetworkInterface", route.get("NetworkInterfaceId")),
        ("Instance", route.get("InstanceId")),
        ("EgressOnlyIGW", route.get("EgressOnlyInternetGatewayId")),
        ("CarrierGateway", route.get("CarrierGatewayId")),
        ("CoreNetwork", route.get("CoreNetworkArn")),
    ]

    for target_type, target_id in possible_targets:
        if target_id:
            return f"{target_type}:{target_id}"

    return "local"


def show_route_tables(ec2) -> None:
    section("ROUTE TABLES")

    response = ec2.describe_route_tables()
    route_tables = response.get("RouteTables", [])

    print_count("route tables", route_tables)

    route_tables = sorted(
        route_tables,
        key=lambda route_table: get_name(route_table.get("Tags")),
    )

    for route_table in route_tables:
        print()
        print(
            f"Name={get_name(route_table.get('Tags'))} "
            f"Tier={get_tag(route_table.get('Tags'), 'Tier')} "
            f"RouteTable_ID={route_table.get('RouteTableId', '-')} "
            f"VPC_ID={route_table.get('VpcId', '-')}"
        )

        associations = route_table.get("Associations", [])

        if associations:
            print("  Associations:")

            for association in associations:
                print(
                    "    "
                    f"Association_ID={association.get('RouteTableAssociationId', '-')} "
                    f"Subnet_ID={association.get('SubnetId', '-')} "
                    f"Main={association.get('Main', False)}"
                )
        else:
            print("  Associations: none")

        routes = route_table.get("Routes", [])

        if routes:
            print("  Routes:")

            for route in routes:
                print(
                    "    "
                    f"{get_route_destination(route)} "
                    f"-> {get_route_target(route)} "
                    f"State={route.get('State', '-')}"
                )
        else:
            print("  Routes: none")


# ============================================================
# Network ACLs
# ============================================================

def show_network_acls(ec2) -> None:
    section("NETWORK ACLS")

    response = ec2.describe_network_acls()
    network_acls = response.get("NetworkAcls", [])

    print_count("Network ACLs", network_acls)

    for nacl in network_acls:
        print()
        print(
            f"Name={get_name(nacl.get('Tags'))} "
            f"Tier={get_tag(nacl.get('Tags'), 'Tier')} "
            f"NACL_ID={nacl.get('NetworkAclId', '-')} "
            f"VPC_ID={nacl.get('VpcId', '-')} "
            f"Default={nacl.get('IsDefault', False)}"
        )

        associations = nacl.get("Associations", [])

        if associations:
            print("  Associations:")

            for association in associations:
                print(
                    "    "
                    f"Subnet_ID={association.get('SubnetId', '-')} "
                    f"Association_ID={association.get('NetworkAclAssociationId', '-')}"
                )

        entries = sorted(
            nacl.get("Entries", []),
            key=lambda entry: (
                entry.get("Egress", False),
                entry.get("RuleNumber", 0),
            ),
        )

        if entries:
            print("  Rules:")

            for entry in entries:
                direction = "EGRESS" if entry.get("Egress") else "INGRESS"

                cidr = (
                    entry.get("CidrBlock")
                    or entry.get("Ipv6CidrBlock")
                    or "-"
                )

                port_range = entry.get("PortRange", {})

                from_port = port_range.get("From")
                to_port = port_range.get("To")

                if from_port is None or to_port is None:
                    ports = "ALL"
                elif from_port == to_port:
                    ports = str(from_port)
                else:
                    ports = f"{from_port}-{to_port}"

                print(
                    "    "
                    f"{direction} "
                    f"Rule={entry.get('RuleNumber', '-')} "
                    f"Protocol={entry.get('Protocol', '-')} "
                    f"CIDR={cidr} "
                    f"Ports={ports} "
                    f"Action={entry.get('RuleAction', '-')}"
                )


# ============================================================
# VPC Endpoints
# ============================================================

def show_vpc_endpoints(ec2) -> None:
    section("VPC ENDPOINTS")

    response = ec2.describe_vpc_endpoints()
    endpoints = response.get("VpcEndpoints", [])

    print_count("VPC Endpoints", endpoints)

    for endpoint in endpoints:
        route_table_ids = endpoint.get("RouteTableIds", [])
        subnet_ids = endpoint.get("SubnetIds", [])

        print(
            f"Name={get_name(endpoint.get('Tags'))} "
            f"Endpoint_ID={endpoint.get('VpcEndpointId', '-')} "
            f"VPC_ID={endpoint.get('VpcId', '-')} "
            f"Service={endpoint.get('ServiceName', '-')} "
            f"Type={endpoint.get('VpcEndpointType', '-')} "
            f"State={endpoint.get('State', '-')} "
            f"RouteTables={','.join(route_table_ids) if route_table_ids else '-'} "
            f"Subnets={','.join(subnet_ids) if subnet_ids else '-'}"
        )


# ============================================================
# VPC Flow Logs
# ============================================================

def show_flow_logs(ec2) -> None:
    section("VPC FLOW LOGS")

    response = ec2.describe_flow_logs()
    flow_logs = response.get("FlowLogs", [])

    print_count("VPC Flow Logs", flow_logs)

    for flow_log in flow_logs:
        print(
            f"FlowLog_ID={flow_log.get('FlowLogId', '-')} "
            f"Resource_ID={flow_log.get('ResourceId', '-')} "
            f"TrafficType={flow_log.get('TrafficType', '-')} "
            f"DestinationType={flow_log.get('LogDestinationType', '-')} "
            f"Destination={flow_log.get('LogDestination', '-')} "
            f"Status={flow_log.get('FlowLogStatus', '-')}"
        )


# ============================================================
# Network Summary
# ============================================================

def show_summary(ec2) -> None:
    section("NETWORK SUMMARY")

    vpc_count = len(ec2.describe_vpcs().get("Vpcs", []))
    subnet_count = len(ec2.describe_subnets().get("Subnets", []))
    igw_count = len(
        ec2.describe_internet_gateways().get(
            "InternetGateways",
            [],
        )
    )
    nat_count = len(
        ec2.describe_nat_gateways().get(
            "NatGateways",
            [],
        )
    )
    route_table_count = len(
        ec2.describe_route_tables().get(
            "RouteTables",
            [],
        )
    )
    nacl_count = len(
        ec2.describe_network_acls().get(
            "NetworkAcls",
            [],
        )
    )
    endpoint_count = len(
        ec2.describe_vpc_endpoints().get(
            "VpcEndpoints",
            [],
        )
    )
    flow_log_count = len(
        ec2.describe_flow_logs().get(
            "FlowLogs",
            [],
        )
    )

    print(f"VPCs={vpc_count}")
    print(f"Subnets={subnet_count}")
    print(f"InternetGateways={igw_count}")
    print(f"NATGateways={nat_count}")
    print(f"RouteTables={route_table_count}")
    print(f"NetworkACLs={nacl_count}")
    print(f"VPCEndpoints={endpoint_count}")
    print(f"FlowLogs={flow_log_count}")


# ============================================================
# Main
# ============================================================

def main() -> int:
    try:
        ec2 = get_ec2_client()

        show_vpcs(ec2)
        show_subnets(ec2)
        show_internet_gateways(ec2)
        show_elastic_ips(ec2)
        show_nat_gateways(ec2)
        show_route_tables(ec2)
        show_network_acls(ec2)
        show_vpc_endpoints(ec2)
        show_flow_logs(ec2)
        show_summary(ec2)

        section("COMPLETED")
        print("Network resources displayed successfully.")

        return 0

    except EndpointConnectionError as exc:
        print(
            f"[ERROR] Unable to connect to LocalStack/AWS endpoint: {exc}",
            file=sys.stderr,
        )
        return 1

    except ClientError as exc:
        error = exc.response.get("Error", {})

        print(
            "[ERROR] AWS API request failed: "
            f"Code={error.get('Code', '-')} "
            f"Message={error.get('Message', '-')}",
            file=sys.stderr,
        )

        return 1

    except BotoCoreError as exc:
        print(
            f"[ERROR] Boto3/Botocore error: {exc}",
            file=sys.stderr,
        )
        return 1

    except Exception as exc:
        print(
            f"[ERROR] Unexpected error: {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())