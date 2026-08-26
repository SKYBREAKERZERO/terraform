#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

DB_IDENTIFIER="${RDS_DB_IDENTIFIER:-${PROJECT_NAME}-${ENVIRONMENT}-mysql}"


print_section() {
    local title="$1"

    echo
    echo "========================================================================"
    echo "${title}"
    echo "========================================================================"
}


print_field() {
    local name="$1"
    local value="${2:--}"

    printf "%-32s: %s\n" "${name}" "${value}"
}


check_dependencies() {
    local missing=0

    for command_name in aws jq; do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            echo "[ERROR] Required command not found: ${command_name}" >&2
            missing=1
        fi
    done

    if [[ "${missing}" -ne 0 ]]; then
        exit 1
    fi
}


aws_local() {
    aws \
        --endpoint-url "${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        "$@"
}


get_db_instance() {
    aws_local rds describe-db-instances \
        --db-instance-identifier "${DB_IDENTIFIER}" \
        --output json
}


get_db_subnet_group() {
    local subnet_group_name="$1"

    aws_local rds describe-db-subnet-groups \
        --db-subnet-group-name "${subnet_group_name}" \
        --output json
}


get_tags() {
    local resource_arn="$1"

    aws_local rds list-tags-for-resource \
        --resource-name "${resource_arn}" \
        --output json
}


main() {
    check_dependencies

    print_section "RDS Inventory"

    print_field "Region" "${AWS_REGION}"
    print_field "Endpoint" "${LOCALSTACK_ENDPOINT}"
    print_field "DB Identifier" "${DB_IDENTIFIER}"

    local db_response
    local db

    if ! db_response="$(get_db_instance 2>/dev/null)"; then
        echo
        echo "[ERROR] RDS instance not found or RDS API is unavailable: ${DB_IDENTIFIER}" >&2
        exit 1
    fi

    db="$(
        jq -c '.DBInstances[0] // empty' \
            <<<"${db_response}"
    )"

    if [[ -z "${db}" ]]; then
        echo
        echo "[ERROR] RDS instance not found: ${DB_IDENTIFIER}" >&2
        exit 1
    fi


    # ------------------------------------------------------------------
    # DB Instance
    # ------------------------------------------------------------------

    print_section "RDS DB Instance"

    print_field \
        "DB Identifier" \
        "$(jq -r '.DBInstanceIdentifier // "-"' <<<"${db}")"

    print_field \
        "DB Instance ARN" \
        "$(jq -r '.DBInstanceArn // "-"' <<<"${db}")"

    print_field \
        "Status" \
        "$(jq -r '.DBInstanceStatus // "-"' <<<"${db}")"

    print_field \
        "Engine" \
        "$(jq -r '.Engine // "-"' <<<"${db}")"

    print_field \
        "Engine Version" \
        "$(jq -r '.EngineVersion // "-"' <<<"${db}")"

    print_field \
        "Instance Class" \
        "$(jq -r '.DBInstanceClass // "-"' <<<"${db}")"

    print_field \
        "Database Name" \
        "$(jq -r '.DBName // "-"' <<<"${db}")"

    print_field \
        "Endpoint" \
        "$(jq -r '.Endpoint.Address // "-"' <<<"${db}")"

    print_field \
        "Port" \
        "$(jq -r '.Endpoint.Port // "-"' <<<"${db}")"

    print_field \
        "Availability Zone" \
        "$(jq -r '.AvailabilityZone // "-"' <<<"${db}")"

    print_field \
        "Multi-AZ" \
        "$(jq -r '.MultiAZ // "-"' <<<"${db}")"

    print_field \
        "Publicly Accessible" \
        "$(jq -r '.PubliclyAccessible // "-"' <<<"${db}")"


    # ------------------------------------------------------------------
    # Network
    # ------------------------------------------------------------------

    print_section "Network"

    local subnet_group_name
    local vpc_id
    local security_groups

    subnet_group_name="$(
        jq -r '.DBSubnetGroup.DBSubnetGroupName // empty' \
            <<<"${db}"
    )"

    vpc_id="$(
        jq -r '.DBSubnetGroup.VpcId // "-"' \
            <<<"${db}"
    )"

    security_groups="$(
        jq -r '
            [
                .VpcSecurityGroups[]?
                | .VpcSecurityGroupId
            ]
            | if length == 0
              then "-"
              else join(", ")
              end
        ' <<<"${db}"
    )"

    print_field \
        "Subnet Group" \
        "${subnet_group_name:--}"

    print_field \
        "Subnet Group Status" \
        "$(jq -r '.DBSubnetGroup.SubnetGroupStatus // "-"' <<<"${db}")"

    print_field \
        "VPC ID" \
        "${vpc_id}"

    print_field \
        "Security Groups" \
        "${security_groups}"


    # ------------------------------------------------------------------
    # DB Subnets
    # ------------------------------------------------------------------

    print_section "DB Subnets"

    if [[ -n "${subnet_group_name}" ]]; then
        local subnet_response

        if subnet_response="$(
            get_db_subnet_group "${subnet_group_name}" 2>/dev/null
        )"; then

            local subnet_count

            subnet_count="$(
                jq '
                    .DBSubnetGroups[0].Subnets
                    | length
                ' <<<"${subnet_response}"
            )"

            if [[ "${subnet_count}" -eq 0 ]]; then
                echo "No subnets found."
            else
                jq -c '
                    .DBSubnetGroups[0].Subnets[]?
                ' <<<"${subnet_response}" |
                while IFS= read -r subnet; do
                    print_field \
                        "Subnet ID" \
                        "$(jq -r '.SubnetIdentifier // "-"' <<<"${subnet}")"

                    print_field \
                        "Availability Zone" \
                        "$(jq -r '.SubnetAvailabilityZone.Name // "-"' <<<"${subnet}")"

                    print_field \
                        "Status" \
                        "$(jq -r '.SubnetStatus // "-"' <<<"${subnet}")"

                    echo "------------------------------------------------------------------------"
                done
            fi
        else
            echo "Unable to retrieve DB subnet group."
        fi
    else
        echo "No DB subnet group information available."
    fi


    # ------------------------------------------------------------------
    # Storage
    # ------------------------------------------------------------------

    print_section "Storage"

    print_field \
        "Allocated Storage (GiB)" \
        "$(jq -r '.AllocatedStorage // "-"' <<<"${db}")"

    print_field \
        "Max Allocated Storage" \
        "$(jq -r '.MaxAllocatedStorage // "-"' <<<"${db}")"

    print_field \
        "Storage Type" \
        "$(jq -r '.StorageType // "-"' <<<"${db}")"

    print_field \
        "Storage Encrypted" \
        "$(jq -r '.StorageEncrypted // "-"' <<<"${db}")"

    print_field \
        "KMS Key ID" \
        "$(jq -r '.KmsKeyId // "-"' <<<"${db}")"


    # ------------------------------------------------------------------
    # Backup / Maintenance
    # ------------------------------------------------------------------

    print_section "Backup / Maintenance"

    print_field \
        "Backup Retention (days)" \
        "$(jq -r '.BackupRetentionPeriod // "-"' <<<"${db}")"

    print_field \
        "Backup Window" \
        "$(jq -r '.PreferredBackupWindow // "-"' <<<"${db}")"

    print_field \
        "Maintenance Window" \
        "$(jq -r '.PreferredMaintenanceWindow // "-"' <<<"${db}")"

    print_field \
        "Latest Restorable Time" \
        "$(jq -r '.LatestRestorableTime // "-"' <<<"${db}")"


    # ------------------------------------------------------------------
    # Monitoring
    # ------------------------------------------------------------------

    print_section "Monitoring"

    print_field \
        "Monitoring Interval" \
        "$(jq -r '.MonitoringInterval // "-"' <<<"${db}")"

    print_field \
        "Monitoring Role ARN" \
        "$(jq -r '.MonitoringRoleArn // "-"' <<<"${db}")"

    print_field \
        "Performance Insights" \
        "$(jq -r '.PerformanceInsightsEnabled // "-"' <<<"${db}")"

    print_field \
        "CloudWatch Logs" \
        "$(
            jq -r '
                .EnabledCloudwatchLogsExports
                // []
                | if length == 0
                  then "-"
                  else join(", ")
                  end
            ' <<<"${db}"
        )"


    # ------------------------------------------------------------------
    # Protection
    # ------------------------------------------------------------------

    print_section "Protection"

    print_field \
        "Deletion Protection" \
        "$(jq -r '.DeletionProtection // "-"' <<<"${db}")"

    print_field \
        "Auto Minor Upgrade" \
        "$(jq -r '.AutoMinorVersionUpgrade // "-"' <<<"${db}")"


    # ------------------------------------------------------------------
    # Tags
    # ------------------------------------------------------------------

    print_section "Tags"

    local resource_arn

    resource_arn="$(
        jq -r '.DBInstanceArn // empty' \
            <<<"${db}"
    )"

    if [[ -z "${resource_arn}" ]]; then
        echo "No resource ARN returned."
    else
        local tags_response

        if tags_response="$(
            get_tags "${resource_arn}" 2>/dev/null
        )"; then

            local tag_count

            tag_count="$(
                jq '.TagList | length' \
                    <<<"${tags_response}"
            )"

            if [[ "${tag_count}" -eq 0 ]]; then
                echo "No tags found."
            else
                jq -r '
                    .TagList
                    | sort_by(.Key)
                    | .[]
                    | [.Key, (.Value // "")]
                    | @tsv
                ' <<<"${tags_response}" |
                while IFS=$'\t' read -r key value; do
                    print_field "${key}" "${value}"
                done
            fi
        else
            echo "Unable to retrieve tags."
        fi
    fi

    echo
}


main "$@"