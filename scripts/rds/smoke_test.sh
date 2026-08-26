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
EXPECTED_STORAGE_TYPE="${RDS_EXPECTED_STORAGE_TYPE:-gp3}"

EXPECTED_BACKUP_RETENTION="${RDS_EXPECTED_BACKUP_RETENTION:-7}"
EXPECTED_SUBNET_COUNT="${RDS_EXPECTED_SUBNET_COUNT:-2}"

EXPECTED_MULTI_AZ="${RDS_EXPECTED_MULTI_AZ:-false}"
EXPECTED_PUBLICLY_ACCESSIBLE="${RDS_EXPECTED_PUBLICLY_ACCESSIBLE:-false}"
EXPECTED_STORAGE_ENCRYPTED="${RDS_EXPECTED_STORAGE_ENCRYPTED:-true}"
EXPECTED_DELETION_PROTECTION="${RDS_EXPECTED_DELETION_PROTECTION:-false}"


# ============================================================
# Counters
# ============================================================

PASS_COUNT=0
FAIL_COUNT=0


# ============================================================
# Helpers
# ============================================================

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] $*"
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


aws_local() {
    aws \
        --endpoint-url "${LOCALSTACK_ENDPOINT}" \
        --region "${AWS_REGION}" \
        "$@"
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


# ============================================================
# Main
# ============================================================

main() {
    print_section "RDS Smoke Test"

    echo "Region        : ${AWS_REGION}"
    echo "Endpoint      : ${LOCALSTACK_ENDPOINT}"
    echo "DB Identifier : ${DB_IDENTIFIER}"

    echo


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
    # LocalStack API
    # ========================================================

    print_section "LocalStack / RDS API"

    local db_response

    if db_response="$(
        aws_local rds describe-db-instances \
            --db-instance-identifier "${DB_IDENTIFIER}" \
            --output json 2>/dev/null
    )"; then
        pass "RDS API is reachable"
    else
        fail "RDS API is not reachable or DB instance does not exist"
        print_summary
        exit 1
    fi


    # ========================================================
    # DB Instance
    # ========================================================

    print_section "DB Instance"

    local db_identifier
    local db_status
    local engine
    local instance_class
    local database_name

    db_identifier="$(
        jq -r '.DBInstances[0].DBInstanceIdentifier // empty' \
            <<<"${db_response}"
    )"

    db_status="$(
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


    if [[ "${db_identifier}" == "${DB_IDENTIFIER}" ]]; then
        pass "DB instance exists: ${db_identifier}"
    else
        fail "DB identifier mismatch: actual=${db_identifier}, expected=${DB_IDENTIFIER}"
    fi


    if [[ "${db_status}" == "available" ]]; then
        pass "DB instance status is available"
    else
        fail "DB instance status is not available: ${db_status}"
    fi


    if [[ "${engine}" == "${EXPECTED_ENGINE}" ]]; then
        pass "Database engine is correct: ${engine}"
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


    if [[ -n "${subnet_group_name}" ]]; then
        pass "DB subnet group is attached: ${subnet_group_name}"
    else
        fail "DB subnet group is not attached"
    fi


    if [[ "${security_group_count}" -ge 1 ]]; then
        pass "RDS has at least one security group attached"
    else
        fail "RDS has no security group attached"
    fi


    # ========================================================
    # DB Subnet Group
    # ========================================================

    print_section "DB Subnet Group"

    if [[ -n "${subnet_group_name}" ]]; then

        local subnet_response

        if subnet_response="$(
            aws_local rds describe-db-subnet-groups \
                --db-subnet-group-name "${subnet_group_name}" \
                --output json 2>/dev/null
        )"; then
            pass "DB subnet group is retrievable"
        else
            fail "Unable to retrieve DB subnet group: ${subnet_group_name}"
            subnet_response=""
        fi


        if [[ -n "${subnet_response}" ]]; then

            local subnet_status
            local subnet_count
            local az_count

            subnet_status="$(
                jq -r '
                    .DBSubnetGroups[0].SubnetGroupStatus
                    // empty
                ' <<<"${subnet_response}"
            )"

            subnet_count="$(
                jq '
                    .DBSubnetGroups[0].Subnets
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


            if [[ "${az_count}" -ge 2 ]]; then
                pass "DB subnet group spans multiple Availability Zones"
            else
                fail "DB subnet group does not span at least two Availability Zones"
            fi
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
        fail "Allocated storage is below minimum expectation: ${allocated_storage} GiB"
    fi


    if [[ "${storage_type}" == "${EXPECTED_STORAGE_TYPE}" ]]; then
        pass "Storage type is correct: ${storage_type}"
    else
        fail "Storage type mismatch: actual=${storage_type}, expected=${EXPECTED_STORAGE_TYPE}"
    fi


    if [[ "$(normalize_bool "${storage_encrypted}")" == "$(normalize_bool "${EXPECTED_STORAGE_ENCRYPTED}")" ]]; then
        pass "Storage encryption setting is correct: ${storage_encrypted}"
    else
        fail "Storage encryption mismatch: actual=${storage_encrypted}, expected=${EXPECTED_STORAGE_ENCRYPTED}"
    fi


    # ========================================================
    # Backup
    # ========================================================

    print_section "Backup"

    local backup_retention

    backup_retention="$(
        jq -r '.DBInstances[0].BackupRetentionPeriod // -1' \
            <<<"${db_response}"
    )"


    if [[ "${backup_retention}" -eq "${EXPECTED_BACKUP_RETENTION}" ]]; then
        pass "Backup retention is correct: ${backup_retention} days"
    else
        fail "Backup retention mismatch: actual=${backup_retention}, expected=${EXPECTED_BACKUP_RETENTION}"
    fi


    # ========================================================
    # Protection
    # ========================================================

    print_section "Protection"

    local deletion_protection

    deletion_protection="$(
        jq -r '.DBInstances[0].DeletionProtection // empty' \
            <<<"${db_response}"
    )"


    if [[ "$(normalize_bool "${deletion_protection}")" == "$(normalize_bool "${EXPECTED_DELETION_PROTECTION}")" ]]; then
        pass "Deletion protection setting is correct: ${deletion_protection}"
    else
        fail "Deletion protection mismatch: actual=${deletion_protection}, expected=${EXPECTED_DELETION_PROTECTION}"
    fi


    # ========================================================
    # Guardrails
    # ========================================================

    print_section "Guardrails"

    if [[ "${publicly_accessible}" == "false" ]]; then
        pass "Private database guardrail passed: no public RDS access"
    else
        fail "Private database guardrail failed: RDS is publicly accessible"
    fi


    if [[ "${storage_encrypted}" == "true" ]]; then
        pass "Encryption guardrail passed"
    else
        fail "Encryption guardrail failed"
    fi


    # ========================================================
    # Summary
    # ========================================================

    print_summary

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        echo
        echo "[FAILED] RDS smoke test failed."
        exit 1
    fi

    echo
    echo "[SUCCESS] RDS smoke test passed."
}


print_summary() {
    echo
    echo "========================================================================"
    echo "Smoke Test Summary"
    echo "========================================================================"

    echo "PASS : ${PASS_COUNT}"
    echo "FAIL : ${FAIL_COUNT}"
}


main "$@"