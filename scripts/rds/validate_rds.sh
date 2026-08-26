#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Configuration
# ============================================================

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"

PROJECT_NAME="${PROJECT_NAME:-aws-enterprise-lab}"
ENVIRONMENT="${ENVIRONMENT:-localstack}"

DB_IDENTIFIER="${RDS_DB_IDENTIFIER:-${PROJECT_NAME}-${ENVIRONMENT}-mysql}"

EXPECTED_ENGINE="${RDS_EXPECTED_ENGINE:-mysql}"
EXPECTED_INSTANCE_CLASS="${RDS_EXPECTED_INSTANCE_CLASS:-db.t3.micro}"
EXPECTED_DATABASE_NAME="${RDS_EXPECTED_DATABASE_NAME:-appdb}"

EXPECTED_SUBNET_GROUP="${RDS_EXPECTED_SUBNET_GROUP:-${PROJECT_NAME}-${ENVIRONMENT}-db-subnet-group}"
EXPECTED_SUBNET_COUNT="${RDS_EXPECTED_SUBNET_COUNT:-2}"

EXPECTED_STORAGE_TYPE="${RDS_EXPECTED_STORAGE_TYPE:-gp3}"
EXPECTED_BACKUP_RETENTION="${RDS_EXPECTED_BACKUP_RETENTION:-7}"

EXPECTED_MULTI_AZ="${RDS_EXPECTED_MULTI_AZ:-false}"
EXPECTED_PUBLICLY_ACCESSIBLE="${RDS_EXPECTED_PUBLICLY_ACCESSIBLE:-false}"
EXPECTED_STORAGE_ENCRYPTED="${RDS_EXPECTED_STORAGE_ENCRYPTED:-true}"
EXPECTED_DELETION_PROTECTION="${RDS_EXPECTED_DELETION_PROTECTION:-false}"
EXPECTED_AUTO_MINOR_UPGRADE="${RDS_EXPECTED_AUTO_MINOR_VERSION_UPGRADE:-true}"

EXPECTED_COMPONENT_TAG="${RDS_EXPECTED_COMPONENT_TAG:-database}"
EXPECTED_SERVICE_TAG="${RDS_EXPECTED_SERVICE_TAG:-rds}"
EXPECTED_TIER_TAG="${RDS_EXPECTED_TIER_TAG:-private-db}"


# ============================================================
# Counters
# ============================================================

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0


# ============================================================
# Helpers
# ============================================================

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] $*"
}


warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo "[WARN] $*"
}


fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] $*" >&2
}


print_section() {
    local title="$1"

    echo
    echo "========================================================================"
    echo "${title}"
    echo "========================================================================"
}


print_summary() {
    echo
    echo "========================================================================"
    echo "Validation Summary"
    echo "========================================================================"

    echo "PASS : ${PASS_COUNT}"
    echo "WARN : ${WARN_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"
}


aws_local() {
    aws \
        --endpoint-url "${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        "$@"
}


normalize_bool() {
    local value="${1,,}"

    case "${value}" in
        true|1|yes)
            echo "true"
            ;;
        false|0|no)
            echo "false"
            ;;
        *)
            echo "${value}"
            ;;
    esac
}


check_dependencies() {
    local command_name

    for command_name in aws jq; do
        if command -v "${command_name}" >/dev/null 2>&1; then
            pass "Required command is available: ${command_name}"
        else
            fail "Required command is missing: ${command_name}"
        fi
    done
}


# ============================================================
# Main
# ============================================================

main() {
    print_section "RDS Validation"

    echo "Region        : ${AWS_REGION}"
    echo "Endpoint      : ${LOCALSTACK_ENDPOINT}"
    echo "DB Identifier : ${DB_IDENTIFIER}"


    # ========================================================
    # Dependencies
    # ========================================================

    print_section "Dependencies"

    check_dependencies

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        print_summary
        exit 1
    fi


    # ========================================================
    # RDS API / Instance
    # ========================================================

    print_section "RDS Instance"

    local db_response

    if db_response="$(
        aws_local rds describe-db-instances \
            --db-instance-identifier "${DB_IDENTIFIER}" \
            --output json 2>/dev/null
    )"; then
        pass "RDS API is reachable"
    else
        fail "RDS API unavailable or DB instance not found: ${DB_IDENTIFIER}"
        print_summary
        exit 1
    fi


    local actual_identifier
    local status
    local engine
    local instance_class
    local database_name

    actual_identifier="$(
        jq -r '.DBInstances[0].DBInstanceIdentifier // empty' \
            <<<"${db_response}"
    )"

    status="$(
        jq -r '.DBInstances[0].DBInstanceStatus // empty' \
            <<<"${db_response}"
    )"

    engine="$(
        jq -r '.DBInstances[0].Engine // empty' \
            <<<"${db_response}"
    )"

    instance_class="$(
        jq -r '.DBInstances[0].DBInstanceClass // empty' \
            <<<"${db_response}"
    )"

    database_name="$(
        jq -r '.DBInstances[0].DBName // empty' \
            <<<"${db_response}"
    )"


    if [[ "${actual_identifier}" == "${DB_IDENTIFIER}" ]]; then
        pass "DB identifier is correct: ${actual_identifier}"
    else
        fail "DB identifier mismatch: actual=${actual_identifier}, expected=${DB_IDENTIFIER}"
    fi


    if [[ "${status}" == "available" ]]; then
        pass "DB status is available"
    else
        warn "DB status is ${status}"
    fi


    if [[ "${engine}" == "${EXPECTED_ENGINE}" ]]; then
        pass "Engine is correct: ${engine}"
    else
        fail "Engine mismatch: actual=${engine}, expected=${EXPECTED_ENGINE}"
    fi


    if [[ "${instance_class}" == "${EXPECTED_INSTANCE_CLASS}" ]]; then
        pass "Instance class is correct: ${instance_class}"
    else
        fail "Instance class mismatch: actual=${instance_class}, expected=${EXPECTED_INSTANCE_CLASS}"
    fi


    if [[ "${database_name}" == "${EXPECTED_DATABASE_NAME}" ]]; then
        pass "Database name is correct: ${database_name}"
    else
        fail "Database name mismatch: actual=${database_name}, expected=${EXPECTED_DATABASE_NAME}"
    fi


    # ========================================================
    # Network
    # ========================================================

    print_section "Network"

    local publicly_accessible
    local subnet_group_name
    local security_group_count

    publicly_accessible="$(
        jq -r '.DBInstances[0].PubliclyAccessible // empty' \
            <<<"${db_response}"
    )"

    subnet_group_name="$(
        jq -r '.DBInstances[0].DBSubnetGroup.DBSubnetGroupName // empty' \
            <<<"${db_response}"
    )"

    security_group_count="$(
        jq '
            [
                .DBInstances[0].VpcSecurityGroups[]?
                | .VpcSecurityGroupId
            ]
            | length
        ' <<<"${db_response}"
    )"


    if [[ "$(normalize_bool "${publicly_accessible}")" == "$(normalize_bool "${EXPECTED_PUBLICLY_ACCESSIBLE}")" ]]; then
        pass "Public accessibility is correct: ${publicly_accessible}"
    else
        fail "Public accessibility mismatch: actual=${publicly_accessible}, expected=${EXPECTED_PUBLICLY_ACCESSIBLE}"
    fi


    if [[ "${subnet_group_name}" == "${EXPECTED_SUBNET_GROUP}" ]]; then
        pass "DB subnet group is correct: ${subnet_group_name}"
    else
        fail "DB subnet group mismatch: actual=${subnet_group_name}, expected=${EXPECTED_SUBNET_GROUP}"
    fi


    if [[ "${security_group_count}" -ge 1 ]]; then
        pass "At least one VPC security group is attached"
    else
        fail "No VPC security group is attached"
    fi


    # ========================================================
    # DB Subnet Group
    # ========================================================

    print_section "DB Subnet Group"

    local subnet_response=""

    if [[ -n "${subnet_group_name}" ]]; then
        if subnet_response="$(
            aws_local rds describe-db-subnet-groups \
                --db-subnet-group-name "${subnet_group_name}" \
                --output json 2>/dev/null
        )"; then
            pass "DB subnet group is retrievable"
        else
            fail "Unable to retrieve DB subnet group: ${subnet_group_name}"
        fi
    else
        fail "DB subnet group name is missing"
    fi


    if [[ -n "${subnet_response}" ]]; then

        local subnet_status
        local subnet_count
        local unique_subnet_count
        local az_count

        subnet_status="$(
            jq -r '.DBSubnetGroups[0].SubnetGroupStatus // empty' \
                <<<"${subnet_response}"
        )"

        subnet_count="$(
            jq '.DBSubnetGroups[0].Subnets | length' \
                <<<"${subnet_response}"
        )"

        unique_subnet_count="$(
            jq '
                [
                    .DBSubnetGroups[0].Subnets[]?
                    | .SubnetIdentifier
                ]
                | unique
                | length
            ' <<<"${subnet_response}"
        )"

        az_count="$(
            jq '
                [
                    .DBSubnetGroups[0].Subnets[]?
                    | .SubnetAvailabilityZone.Name
                ]
                | unique
                | length
            ' <<<"${subnet_response}"
        )"


        if [[ "${subnet_status}" == "Complete" ]]; then
            pass "DB subnet group status is Complete"
        else
            fail "Unexpected DB subnet group status: ${subnet_status}"
        fi


        if [[ "${subnet_count}" -eq "${EXPECTED_SUBNET_COUNT}" ]]; then
            pass "DB subnet count is correct: ${subnet_count}"
        else
            fail "DB subnet count mismatch: actual=${subnet_count}, expected=${EXPECTED_SUBNET_COUNT}"
        fi


        if [[ "${unique_subnet_count}" -eq "${subnet_count}" ]]; then
            pass "All DB subnet IDs are unique"
        else
            fail "Duplicate DB subnet IDs detected"
        fi


        if [[ "${az_count}" -ge 2 ]]; then
            pass "DB subnet group spans at least two Availability Zones"
        else
            fail "DB subnet group does not span at least two Availability Zones"
        fi
    fi


    # ========================================================
    # Availability
    # ========================================================

    print_section "Availability"

    local multi_az

    multi_az="$(
        jq -r '.DBInstances[0].MultiAZ // empty' \
            <<<"${db_response}"
    )"


    if [[ "$(normalize_bool "${multi_az}")" == "$(normalize_bool "${EXPECTED_MULTI_AZ}")" ]]; then
        pass "Multi-AZ setting is correct: ${multi_az}"
    else
        fail "Multi-AZ mismatch: actual=${multi_az}, expected=${EXPECTED_MULTI_AZ}"
    fi


    # ========================================================
    # Storage
    # ========================================================

    print_section "Storage"

    local allocated_storage
    local storage_type
    local storage_encrypted

    allocated_storage="$(
        jq -r '.DBInstances[0].AllocatedStorage // 0' \
            <<<"${db_response}"
    )"

    storage_type="$(
        jq -r '.DBInstances[0].StorageType // empty' \
            <<<"${db_response}"
    )"

    storage_encrypted="$(
        jq -r '.DBInstances[0].StorageEncrypted // empty' \
            <<<"${db_response}"
    )"


    if [[ "${allocated_storage}" -ge 20 ]]; then
        pass "Allocated storage is valid: ${allocated_storage} GiB"
    else
        fail "Allocated storage is invalid: ${allocated_storage} GiB"
    fi


    if [[ "${storage_type}" == "${EXPECTED_STORAGE_TYPE}" ]]; then
        pass "Storage type is correct: ${storage_type}"
    else
        fail "Storage type mismatch: actual=${storage_type}, expected=${EXPECTED_STORAGE_TYPE}"
    fi


    if [[ "$(normalize_bool "${storage_encrypted}")" == "$(normalize_bool "${EXPECTED_STORAGE_ENCRYPTED}")" ]]; then
        pass "Storage encryption is correct: ${storage_encrypted}"
    else
        fail "Storage encryption mismatch: actual=${storage_encrypted}, expected=${EXPECTED_STORAGE_ENCRYPTED}"
    fi


    # ========================================================
    # Backup / Maintenance
    # ========================================================

    print_section "Backup / Maintenance"

    local backup_retention
    local backup_window
    local maintenance_window

    backup_retention="$(
        jq -r '.DBInstances[0].BackupRetentionPeriod // -1' \
            <<<"${db_response}"
    )"

    backup_window="$(
        jq -r '.DBInstances[0].PreferredBackupWindow // empty' \
            <<<"${db_response}"
    )"

    maintenance_window="$(
        jq -r '.DBInstances[0].PreferredMaintenanceWindow // empty' \
            <<<"${db_response}"
    )"


    if [[ "${backup_retention}" -eq "${EXPECTED_BACKUP_RETENTION}" ]]; then
        pass "Backup retention is correct: ${backup_retention} days"
    else
        fail "Backup retention mismatch: actual=${backup_retention}, expected=${EXPECTED_BACKUP_RETENTION}"
    fi


    if [[ -n "${backup_window}" ]]; then
        pass "Preferred backup window is configured: ${backup_window}"
    else
        warn "Preferred backup window is not returned"
    fi


    if [[ -n "${maintenance_window}" ]]; then
        pass "Preferred maintenance window is configured: ${maintenance_window}"
    else
        warn "Preferred maintenance window is not returned"
    fi


    # ========================================================
    # Protection
    # ========================================================

    print_section "Protection"

    local deletion_protection
    local auto_minor_upgrade

    deletion_protection="$(
        jq -r '.DBInstances[0].DeletionProtection // empty' \
            <<<"${db_response}"
    )"

    auto_minor_upgrade="$(
        jq -r '.DBInstances[0].AutoMinorVersionUpgrade // empty' \
            <<<"${db_response}"
    )"


    if [[ "$(normalize_bool "${deletion_protection}")" == "$(normalize_bool "${EXPECTED_DELETION_PROTECTION}")" ]]; then
        pass "Deletion protection is correct: ${deletion_protection}"
    else
        fail "Deletion protection mismatch: actual=${deletion_protection}, expected=${EXPECTED_DELETION_PROTECTION}"
    fi


    if [[ "$(normalize_bool "${auto_minor_upgrade}")" == "$(normalize_bool "${EXPECTED_AUTO_MINOR_UPGRADE}")" ]]; then
        pass "Auto minor version upgrade is correct: ${auto_minor_upgrade}"
    else
        fail "Auto minor version upgrade mismatch: actual=${auto_minor_upgrade}, expected=${EXPECTED_AUTO_MINOR_UPGRADE}"
    fi


    # ========================================================
    # Monitoring
    # ========================================================

    print_section "Monitoring"

    local monitoring_interval
    local performance_insights

    monitoring_interval="$(
        jq -r '.DBInstances[0].MonitoringInterval // 0' \
            <<<"${db_response}"
    )"

    performance_insights="$(
        jq -r '.DBInstances[0].PerformanceInsightsEnabled // empty' \
            <<<"${db_response}"
    )"


    case "${monitoring_interval}" in
        0|1|5|10|15|30|60)
            pass "Monitoring interval is valid: ${monitoring_interval}"
            ;;
        *)
            fail "Invalid monitoring interval: ${monitoring_interval}"
            ;;
    esac


    if [[ -n "${performance_insights}" ]]; then
        pass "Performance Insights setting is returned: ${performance_insights}"
    else
        warn "Performance Insights setting is not returned"
    fi


    # ========================================================
    # Tags
    # ========================================================

    print_section "Tags"

    local resource_arn
    local tags_response=""

    resource_arn="$(
        jq -r '.DBInstances[0].DBInstanceArn // empty' \
            <<<"${db_response}"
    )"


    if [[ -n "${resource_arn}" ]]; then
        if tags_response="$(
            aws_local rds list-tags-for-resource \
                --resource-name "${resource_arn}" \
                --output json 2>/dev/null
        )"; then
            pass "RDS tags are retrievable"
        else
            fail "Unable to retrieve RDS tags"
        fi
    else
        fail "DB instance ARN is missing"
    fi


    if [[ -n "${tags_response}" ]]; then

        local project_tag
        local environment_tag
        local component_tag
        local service_tag
        local tier_tag

        project_tag="$(
            jq -r '
                .TagList[]
                | select(.Key == "Project")
                | .Value
            ' <<<"${tags_response}"
        )"

        environment_tag="$(
            jq -r '
                .TagList[]
                | select(.Key == "Environment")
                | .Value
            ' <<<"${tags_response}"
        )"

        component_tag="$(
            jq -r '
                .TagList[]
                | select(.Key == "Component")
                | .Value
            ' <<<"${tags_response}"
        )"

        service_tag="$(
            jq -r '
                .TagList[]
                | select(.Key == "Service")
                | .Value
            ' <<<"${tags_response}"
        )"

        tier_tag="$(
            jq -r '
                .TagList[]
                | select(.Key == "Tier")
                | .Value
            ' <<<"${tags_response}"
        )"

        if [[ "${project_tag}" == "${PROJECT_NAME}" ]]; then
            pass "Project tag is correct: ${project_tag}"
        else
            fail "Project tag mismatch: actual=${project_tag:-missing}, expected=${PROJECT_NAME}"
        fi

        if [[ "${environment_tag}" == "${ENVIRONMENT}" ]]; then
            pass "Environment tag is correct: ${environment_tag}"
        else
            fail "Environment tag mismatch: actual=${environment_tag:-missing}, expected=${ENVIRONMENT}"
        fi

        if [[ "${component_tag}" == "${EXPECTED_COMPONENT_TAG}" ]]; then
            pass "Component tag is correct: ${component_tag}"
        else
            fail "Component tag mismatch: actual=${component_tag:-missing}, expected=${EXPECTED_COMPONENT_TAG}"
        fi

        if [[ "${service_tag}" == "${EXPECTED_SERVICE_TAG}" ]]; then
            pass "Service tag is correct: ${service_tag}"
        else
            fail "Service tag mismatch: actual=${service_tag:-missing}, expected=${EXPECTED_SERVICE_TAG}"
        fi

        if [[ "${tier_tag}" == "${EXPECTED_TIER_TAG}" ]]; then
            pass "Tier tag is correct: ${tier_tag}"
        else
            fail "Tier tag mismatch: actual=${tier_tag:-missing}, expected=${EXPECTED_TIER_TAG}"
        fi
    fi

    # ========================================================
    # Guardrails
    # ========================================================

    print_section "Guardrails"

    if [[ "$(normalize_bool "${publicly_accessible}")" == "false" ]]; then
        pass "Private database guardrail passed"
    else
        fail "Private database guardrail failed"
    fi

    if [[ "$(normalize_bool "${storage_encrypted}")" == "true" ]]; then
        pass "Storage encryption guardrail passed"
    else
        fail "Storage encryption guardrail failed"
    fi

    if [[ "${subnet_count:-0}" -ge 2 ]]; then
        pass "Database subnet redundancy guardrail passed"
    else
        fail "Database subnet redundancy guardrail failed"
    fi

    # ========================================================
    # Summary
    # ========================================================

    print_summary

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        echo
        echo "[FAILED] RDS validation failed."
        exit 1
    fi

    echo
    echo "[SUCCESS] RDS validation passed."
}

main "$@"