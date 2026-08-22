#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
export AWS_PAGER=""


# ============================================================
# Functions
# ============================================================

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "[ERROR] Required command not found: $1"
        exit 1
    fi
}


# ============================================================
# Pre-check
# ============================================================

check_command aws
check_command curl

section "LocalStack Health"

if ! curl -fsS "${LOCALSTACK_ENDPOINT}/_localstack/health"; then
    echo
    echo "[ERROR] LocalStack is not reachable at:"
    echo "        ${LOCALSTACK_ENDPOINT}"
    exit 1
fi

echo
echo "[INFO] LocalStack endpoint: ${LOCALSTACK_ENDPOINT}"
echo "[INFO] AWS region:          ${AWS_REGION}"


# ============================================================
# VPC
# ============================================================

section "VPC"

aws ec2 describe-vpcs \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'Vpcs[*].[VpcId,CidrBlock,State,IsDefault]' \
    --output table


# ============================================================
# Subnets
# ============================================================

section "Subnets"

aws ec2 describe-subnets \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' \
    --output table


# ============================================================
# Internet Gateways
# ============================================================

section "Internet Gateways"

aws ec2 describe-internet-gateways \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' \
    --output table


# ============================================================
# Elastic IPs
# ============================================================

section "Elastic IPs"

aws ec2 describe-addresses \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'Addresses[*].[AllocationId,PublicIp,Domain,NetworkInterfaceId]' \
    --output table


# ============================================================
# NAT Gateways
# ============================================================

section "NAT Gateways"

aws ec2 describe-nat-gateways \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'NatGateways[*].[NatGatewayId,SubnetId,State,ConnectivityType,NatGatewayAddresses[0].PublicIp]' \
    --output table


# ============================================================
# Route Tables
# ============================================================

section "Route Tables"

aws ec2 describe-route-tables \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'RouteTables[*].[RouteTableId,VpcId]' \
    --output table


# ============================================================
# Routes
# ============================================================

section "Routes"

aws ec2 describe-route-tables \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'RouteTables[*].Routes[*].[DestinationCidrBlock,GatewayId,NatGatewayId,State]' \
    --output table


# ============================================================
# Route Table Associations
# ============================================================

section "Route Table Associations"

aws ec2 describe-route-tables \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'RouteTables[*].Associations[*].[RouteTableAssociationId,SubnetId,Main]' \
    --output table


# ============================================================
# Network ACLs
# ============================================================

section "Network ACLs"

aws ec2 describe-network-acls \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'NetworkAcls[*].[NetworkAclId,VpcId,IsDefault]' \
    --output table


# ============================================================
# VPC Endpoints
# ============================================================

section "VPC Endpoints"

aws ec2 describe-vpc-endpoints \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'VpcEndpoints[*].[VpcEndpointId,VpcId,ServiceName,VpcEndpointType,State]' \
    --output table


# ============================================================
# VPC Flow Logs
# ============================================================

section "VPC Flow Logs"

aws ec2 describe-flow-logs \
    --endpoint-url "${LOCALSTACK_ENDPOINT}" \
    --region "${AWS_REGION}" \
    --query 'FlowLogs[*].[FlowLogId,ResourceId,TrafficType,LogDestinationType,FlowLogStatus]' \
    --output table


# ============================================================
# Completed
# ============================================================

section "Network Summary Completed"

echo "[INFO] Network resources displayed successfully."