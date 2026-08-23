from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from typing import Any

from botocore.exceptions import BotoCoreError, ClientError

from common.aws_clients import get_iam_client
from common.config import Config


# ============================================================
# Configuration
# ============================================================

PROJECT_NAME = Config.PROJECT_NAME
ENVIRONMENT = Config.ENVIRONMENT
AWS_REGION = Config.AWS_REGION
LOCALSTACK_ENDPOINT = Config.LOCALSTACK_ENDPOINT

PROJECT_PREFIX = f"{PROJECT_NAME}-{ENVIRONMENT}"

IAM_ENABLE_SSM = (
    os.getenv(
        "IAM_ENABLE_SSM",
        "true",
    ).lower()
    == "true"
)

IAM_ENABLE_CLOUDWATCH_AGENT = (
    os.getenv(
        "IAM_ENABLE_CLOUDWATCH_AGENT",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected IAM Resources
# ============================================================

EXPECTED_ROLE_NAME = (
    f"{PROJECT_PREFIX}-ec2-role"
)

EXPECTED_ROLE_DESCRIPTION = (
    "IAM role for private application EC2 instances"
)

EXPECTED_INSTANCE_PROFILE_NAME = (
    f"{PROJECT_PREFIX}-ec2-instance-profile"
)

EXPECTED_SSM_POLICY_NAME = (
    f"{PROJECT_PREFIX}-ssm-core"
)

EXPECTED_CLOUDWATCH_AGENT_POLICY_NAME = (
    f"{PROJECT_PREFIX}-cloudwatch-agent"
)


# ============================================================
# Expected Trust Policy
# ============================================================

EXPECTED_TRUST_ACTION = "sts:AssumeRole"
EXPECTED_TRUST_PRINCIPAL = "ec2.amazonaws.com"


# ============================================================
# Expected Tags
# ============================================================

EXPECTED_ROLE_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "ManagedBy": "terraform",
    "Deployment": ENVIRONMENT,
    "Component": "identity",
    "Service": "ec2",
    "Role": "application",
}

EXPECTED_INSTANCE_PROFILE_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "ManagedBy": "terraform",
    "Deployment": ENVIRONMENT,
    "Component": "identity",
    "Service": "ec2",
    "Name": EXPECTED_INSTANCE_PROFILE_NAME,
}


# ============================================================
# Required SSM Permissions
# ============================================================

REQUIRED_SSM_ACTIONS = {
    "ssm:UpdateInstanceInformation",

    "ssmmessages:CreateControlChannel",
    "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel",

    "ec2messages:AcknowledgeMessage",
    "ec2messages:DeleteMessage",
    "ec2messages:FailMessage",
    "ec2messages:GetEndpoint",
    "ec2messages:GetMessages",
    "ec2messages:SendReply",
}


# ============================================================
# Required CloudWatch Agent Permissions
# ============================================================

REQUIRED_CLOUDWATCH_ACTIONS = {
    "cloudwatch:PutMetricData",

    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:DescribeLogGroups",
    "logs:DescribeLogStreams",
    "logs:PutLogEvents",

    "ec2:DescribeTags",
    "ec2:DescribeVolumes",
}


# ============================================================
# Forbidden Managed Policies
# ============================================================

FORBIDDEN_MANAGED_POLICIES = {
    "AdministratorAccess",
    "PowerUserAccess",
    "IAMFullAccess",
}


# ============================================================
# Result Model
# ============================================================

@dataclass
class ValidationCounters:
    passed: int = 0
    warned: int = 0
    failed: int = 0


COUNTERS = ValidationCounters()


# ============================================================
# Output Helpers
# ============================================================

def section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def info(message: str) -> None:
    print(f"[INFO] {message}")


def passed(message: str) -> None:
    COUNTERS.passed += 1
    print(f"[PASS] {message}")


def warned(message: str) -> None:
    COUNTERS.warned += 1
    print(f"[WARN] {message}")


def failed(message: str) -> None:
    COUNTERS.failed += 1
    print(f"[FAIL] {message}")


# ============================================================
# Generic Helpers
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


def ensure_list(value: Any) -> list[Any]:
    if value is None:
        return []

    if isinstance(value, list):
        return value

    return [value]


def is_no_such_entity(
    exc: ClientError,
) -> bool:

    code = (
        exc.response
        .get("Error", {})
        .get("Code", "")
    )

    return code in {
        "NoSuchEntity",
        "NoSuchEntityException",
    }


def validate_tags(
    actual_tags: dict[str, str],
    expected_tags: dict[str, str],
    resource_name: str,
) -> None:

    for key, expected_value in (
        expected_tags.items()
    ):
        actual_value = actual_tags.get(key)

        if actual_value == expected_value:
            passed(
                f"{resource_name} "
                f"{key} tag={expected_value}"
            )
        else:
            failed(
                f"{resource_name} "
                f"{key} tag={actual_value}, "
                f"expected={expected_value}"
            )


# ============================================================
# Role
# ============================================================

def get_role(
    iam: Any,
) -> dict[str, Any] | None:

    try:
        response = iam.get_role(
            RoleName=EXPECTED_ROLE_NAME
        )

        return response.get("Role")

    except ClientError as exc:

        if is_no_such_entity(exc):
            return None

        raise


def validate_role(
    iam: Any,
    role: dict[str, Any],
) -> None:

    section("EC2 IAM ROLE")

    role_name = role.get("RoleName")

    if role_name == EXPECTED_ROLE_NAME:
        passed(
            f"IAM role exists: "
            f"{EXPECTED_ROLE_NAME}"
        )
    else:
        failed(
            f"IAM role name={role_name}, "
            f"expected={EXPECTED_ROLE_NAME}"
        )

    description = role.get(
        "Description"
    )

    if (
        description
        == EXPECTED_ROLE_DESCRIPTION
    ):
        passed(
            "IAM role description "
            "is correct"
        )
    else:
        failed(
            "IAM role description="
            f"{description}, expected="
            f"{EXPECTED_ROLE_DESCRIPTION}"
        )

    arn = role.get("Arn")

    if arn:
        passed(
            f"IAM role ARN exists: {arn}"
        )
    else:
        failed(
            "IAM role ARN is missing"
        )

    try:
        response = iam.list_role_tags(
            RoleName=EXPECTED_ROLE_NAME
        )

        tags = tags_to_dict(
            response.get("Tags")
        )

        validate_tags(
            tags,
            EXPECTED_ROLE_TAGS,
            "EC2 role",
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            "Unable to retrieve role "
            f"tags: {exc}"
        )


# ============================================================
# Trust Policy
# ============================================================

def get_policy_statements(
    document: dict[str, Any],
) -> list[dict[str, Any]]:

    statements = ensure_list(
        document.get("Statement")
    )

    return [
        statement
        for statement in statements
        if isinstance(
            statement,
            dict,
        )
    ]


def validate_trust_policy(
    role: dict[str, Any],
) -> None:

    section("TRUST POLICY")

    document = role.get(
        "AssumeRolePolicyDocument"
    )

    if not isinstance(
        document,
        dict,
    ):
        failed(
            "Trust policy document "
            "is missing"
        )
        return

    passed(
        "Trust policy document exists"
    )

    statements = (
        get_policy_statements(
            document
        )
    )

    if not statements:
        failed(
            "Trust policy contains "
            "no statements"
        )
        return

    expected_statement_found = False

    wildcard_aws_principal = False
    wildcard_service_principal = False

    for statement in statements:

        effect = statement.get(
            "Effect"
        )

        actions = set(
            ensure_list(
                statement.get("Action")
            )
        )

        principal = statement.get(
            "Principal",
            {},
        )

        if not isinstance(
            principal,
            dict,
        ):
            principal = {}

        services = set(
            ensure_list(
                principal.get("Service")
            )
        )

        aws_principals = set(
            ensure_list(
                principal.get("AWS")
            )
        )

        if (
            effect == "Allow"
            and EXPECTED_TRUST_ACTION
            in actions
            and EXPECTED_TRUST_PRINCIPAL
            in services
        ):
            expected_statement_found = True

        if "*" in aws_principals:
            wildcard_aws_principal = True

        if "*" in services:
            wildcard_service_principal = True

    if expected_statement_found:
        passed(
            "Trust policy allows "
            "EC2 service to call "
            "sts:AssumeRole"
        )
    else:
        failed(
            "Expected EC2 trust "
            "statement is missing"
        )

    if wildcard_aws_principal:
        failed(
            "Trust policy contains "
            "unrestricted AWS principal '*'"
        )
    else:
        passed(
            "No unrestricted AWS "
            "principal"
        )

    if wildcard_service_principal:
        failed(
            "Trust policy contains "
            "unrestricted service "
            "principal '*'"
        )
    else:
        passed(
            "No unrestricted service "
            "principal"
        )


# ============================================================
# Instance Profile
# ============================================================

def get_instance_profile(
    iam: Any,
) -> dict[str, Any] | None:

    try:
        response = (
            iam.get_instance_profile(
                InstanceProfileName=(
                    EXPECTED_INSTANCE_PROFILE_NAME
                )
            )
        )

        return response.get(
            "InstanceProfile"
        )

    except ClientError as exc:

        if is_no_such_entity(exc):
            return None

        raise


def validate_instance_profile(
    iam: Any,
    profile: dict[str, Any],
) -> None:

    section("INSTANCE PROFILE")

    profile_name = profile.get(
        "InstanceProfileName"
    )

    if (
        profile_name
        == EXPECTED_INSTANCE_PROFILE_NAME
    ):
        passed(
            "EC2 instance profile exists: "
            f"{EXPECTED_INSTANCE_PROFILE_NAME}"
        )
    else:
        failed(
            "Instance profile name="
            f"{profile_name}, expected="
            f"{EXPECTED_INSTANCE_PROFILE_NAME}"
        )

    arn = profile.get("Arn")

    if arn:
        passed(
            f"Instance profile ARN "
            f"exists: {arn}"
        )
    else:
        failed(
            "Instance profile ARN "
            "is missing"
        )

    roles = profile.get(
        "Roles",
        [],
    )

    if len(roles) == 1:
        passed(
            "Instance profile contains "
            "exactly one IAM role"
        )
    else:
        failed(
            "Instance profile role "
            f"count={len(roles)}, "
            "expected=1"
        )

    if roles:
        role_name = roles[0].get(
            "RoleName"
        )

        if (
            role_name
            == EXPECTED_ROLE_NAME
        ):
            passed(
                "Instance profile "
                "contains expected "
                "EC2 role"
            )
        else:
            failed(
                "Instance profile role="
                f"{role_name}, expected="
                f"{EXPECTED_ROLE_NAME}"
            )

    profile_tags = tags_to_dict(
        profile.get("Tags")
    )

    # Some LocalStack versions may omit
    # instance-profile Tags from get-instance-profile.
    if profile_tags:
        validate_tags(
            profile_tags,
            EXPECTED_INSTANCE_PROFILE_TAGS,
            "Instance profile",
        )
    else:
        warned(
            "Instance profile tags "
            "were not returned by API"
        )

    try:
        response = (
            iam.list_instance_profiles_for_role(
                RoleName=EXPECTED_ROLE_NAME
            )
        )

        profiles = response.get(
            "InstanceProfiles",
            [],
        )

        matching = [
            item
            for item in profiles
            if item.get(
                "InstanceProfileName"
            )
            == EXPECTED_INSTANCE_PROFILE_NAME
        ]

        if len(matching) == 1:
            passed(
                "Role -> instance profile "
                "association exists"
            )
        else:
            failed(
                "Role -> instance profile "
                "association count="
                f"{len(matching)}, expected=1"
            )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            "Unable to validate role/"
            f"profile association: {exc}"
        )


# ============================================================
# Inline Policy Guardrail
# ============================================================

def validate_inline_policies(
    iam: Any,
) -> None:

    section("INLINE POLICY GUARDRAIL")

    paginator = iam.get_paginator(
        "list_role_policies"
    )

    policy_names: list[str] = []

    for page in paginator.paginate(
        RoleName=EXPECTED_ROLE_NAME
    ):
        policy_names.extend(
            page.get(
                "PolicyNames",
                [],
            )
        )

    if not policy_names:
        passed(
            "IAM role has no "
            "inline policies"
        )
    else:
        failed(
            "Unexpected inline IAM "
            "policies: "
            + ", ".join(
                policy_names
            )
        )


# ============================================================
# Managed Policies
# ============================================================

def list_local_policies(
    iam: Any,
) -> list[dict[str, Any]]:

    result: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_policies"
    )

    for page in paginator.paginate(
        Scope="Local"
    ):
        result.extend(
            page.get(
                "Policies",
                [],
            )
        )

    return result


def get_attached_policies(
    iam: Any,
) -> list[dict[str, Any]]:

    result: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_attached_role_policies"
    )

    for page in paginator.paginate(
        RoleName=EXPECTED_ROLE_NAME
    ):
        result.extend(
            page.get(
                "AttachedPolicies",
                [],
            )
        )

    return result


def get_policy_document(
    iam: Any,
    policy_arn: str,
) -> dict[str, Any] | None:

    response = iam.get_policy(
        PolicyArn=policy_arn
    )

    policy = response.get(
        "Policy",
        {},
    )

    version_id = policy.get(
        "DefaultVersionId"
    )

    if not version_id:
        return None

    response = iam.get_policy_version(
        PolicyArn=policy_arn,
        VersionId=version_id,
    )

    document = (
        response
        .get(
            "PolicyVersion",
            {},
        )
        .get("Document")
    )

    if isinstance(
        document,
        dict,
    ):
        return document

    return None


# ============================================================
# Policy Document Analysis
# ============================================================

def get_allowed_actions(
    document: dict[str, Any],
) -> set[str]:

    result: set[str] = set()

    for statement in (
        get_policy_statements(
            document
        )
    ):

        if statement.get(
            "Effect"
        ) != "Allow":
            continue

        for action in ensure_list(
            statement.get("Action")
        ):

            if isinstance(
                action,
                str,
            ):
                result.add(action)

    return result


def has_action_wildcard(
    document: dict[str, Any],
) -> bool:

    for statement in (
        get_policy_statements(
            document
        )
    ):

        if statement.get(
            "Effect"
        ) != "Allow":
            continue

        actions = ensure_list(
            statement.get("Action")
        )

        if "*" in actions:
            return True

    return False


def validate_policy_actions(
    document: dict[str, Any],
    required_actions: set[str],
    policy_label: str,
) -> None:

    actual_actions = (
        get_allowed_actions(
            document
        )
    )

    for action in sorted(
        required_actions
    ):

        if action in actual_actions:
            passed(
                f"{policy_label} "
                f"permission present: "
                f"{action}"
            )
        else:
            failed(
                f"{policy_label} "
                f"permission missing: "
                f"{action}"
            )

    if has_action_wildcard(
        document
    ):
        failed(
            f"{policy_label} contains "
            "Allow Action='*'"
        )
    else:
        passed(
            f"{policy_label} does not "
            "contain Allow Action='*'"
        )


# ============================================================
# Individual Managed Policy Validation
# ============================================================

def validate_managed_policy(
    iam: Any,
    policies_by_name: dict[
        str,
        dict[str, Any],
    ],
    attached_by_name: dict[
        str,
        dict[str, Any],
    ],
    policy_name: str,
    required_actions: set[str],
    enabled: bool,
    label: str,
) -> None:

    section(
        f"{label.upper()} POLICY"
    )

    policy = policies_by_name.get(
        policy_name
    )

    attachment = attached_by_name.get(
        policy_name
    )

    if not enabled:

        if policy is None:
            passed(
                f"{label} policy "
                "correctly disabled"
            )
        else:
            failed(
                f"{label} policy exists "
                "although feature is disabled"
            )

        if attachment is None:
            passed(
                f"{label} policy "
                "is not attached"
            )
        else:
            failed(
                f"{label} policy remains "
                "attached although disabled"
            )

        return

    if policy is None:
        failed(
            f"{label} policy missing: "
            f"{policy_name}"
        )
        return

    passed(
        f"{label} policy exists: "
        f"{policy_name}"
    )

    policy_arn = policy.get(
        "Arn"
    )

    if policy_arn:
        passed(
            f"{label} policy ARN "
            f"exists: {policy_arn}"
        )
    else:
        failed(
            f"{label} policy ARN "
            "is missing"
        )
        return

    if attachment is not None:
        passed(
            f"{label} policy is "
            "attached to EC2 role"
        )
    else:
        failed(
            f"{label} policy is not "
            "attached to EC2 role"
        )

    try:
        document = get_policy_document(
            iam,
            policy_arn,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            f"Unable to read "
            f"{label} policy: {exc}"
        )
        return

    if document is None:
        failed(
            f"{label} policy "
            "document is unavailable"
        )
        return

    passed(
        f"{label} policy "
        "document is readable"
    )

    validate_policy_actions(
        document,
        required_actions,
        label,
    )


# ============================================================
# Policy Attachment Guardrails
# ============================================================

def validate_policy_attachments(
    attached_policies: list[
        dict[str, Any]
    ],
) -> None:

    section(
        "MANAGED POLICY ATTACHMENTS"
    )

    expected_count = 0

    if IAM_ENABLE_SSM:
        expected_count += 1

    if IAM_ENABLE_CLOUDWATCH_AGENT:
        expected_count += 1

    actual_count = len(
        attached_policies
    )

    if actual_count == expected_count:
        passed(
            "Attached managed policy "
            f"count={expected_count}"
        )
    else:
        failed(
            "Attached managed policy "
            f"count={actual_count}, "
            f"expected={expected_count}"
        )

    attached_names = {
        policy.get("PolicyName")
        for policy in attached_policies
        if policy.get("PolicyName")
    }

    for forbidden_policy in sorted(
        FORBIDDEN_MANAGED_POLICIES
    ):

        if (
            forbidden_policy
            in attached_names
        ):
            failed(
                "Forbidden managed "
                f"policy attached: "
                f"{forbidden_policy}"
            )
        else:
            passed(
                "Forbidden policy not "
                f"attached: "
                f"{forbidden_policy}"
            )


# ============================================================
# Project IAM Resource Validation
# ============================================================

def validate_project_resources(
    iam: Any,
    local_policies: list[
        dict[str, Any]
    ],
) -> None:

    section(
        "PROJECT IAM RESOURCE VALIDATION"
    )

    roles: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_roles"
    )

    for page in paginator.paginate():
        roles.extend(
            page.get(
                "Roles",
                [],
            )
        )

    matching_roles = [
        role
        for role in roles
        if role.get("RoleName")
        == EXPECTED_ROLE_NAME
    ]

    if len(matching_roles) == 1:
        passed(
            "Exactly one project "
            "EC2 role exists"
        )
    else:
        failed(
            "Project EC2 role "
            f"count={len(matching_roles)}, "
            "expected=1"
        )

    profiles: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_instance_profiles"
    )

    for page in paginator.paginate():
        profiles.extend(
            page.get(
                "InstanceProfiles",
                [],
            )
        )

    matching_profiles = [
        profile
        for profile in profiles
        if profile.get(
            "InstanceProfileName"
        )
        == EXPECTED_INSTANCE_PROFILE_NAME
    ]

    if len(
        matching_profiles
    ) == 1:
        passed(
            "Exactly one project EC2 "
            "instance profile exists"
        )
    else:
        failed(
            "Project EC2 instance "
            "profile count="
            f"{len(matching_profiles)}, "
            "expected=1"
        )

    expected_policy_names: set[str] = set()

    if IAM_ENABLE_SSM:
        expected_policy_names.add(
            EXPECTED_SSM_POLICY_NAME
        )

    if IAM_ENABLE_CLOUDWATCH_AGENT:
        expected_policy_names.add(
            EXPECTED_CLOUDWATCH_AGENT_POLICY_NAME
        )

    actual_project_policy_names = {
        policy.get("PolicyName")
        for policy in local_policies
        if (
            isinstance(
                policy.get(
                    "PolicyName"
                ),
                str,
            )
            and policy[
                "PolicyName"
            ].startswith(
                PROJECT_PREFIX
            )
        )
    }

    managed_project_policy_names = {
        name
        for name in (
            actual_project_policy_names
        )
        if name in {
            EXPECTED_SSM_POLICY_NAME,
            EXPECTED_CLOUDWATCH_AGENT_POLICY_NAME,
        }
    }

    if (
        managed_project_policy_names
        == expected_policy_names
    ):
        passed(
            "Expected project IAM "
            "policy set is correct"
        )
    else:
        failed(
            "Project IAM policies="
            f"{sorted(managed_project_policy_names)}, "
            "expected="
            f"{sorted(expected_policy_names)}"
        )


# ============================================================
# Summary
# ============================================================

def print_summary() -> int:

    section("VALIDATION SUMMARY")

    print(
        f"PASS : {COUNTERS.passed}"
    )

    print(
        f"WARN : {COUNTERS.warned}"
    )

    print(
        f"FAIL : {COUNTERS.failed}"
    )

    print()

    if COUNTERS.failed == 0:
        print(
            "[SUCCESS] IAM validation passed."
        )
        return 0

    print(
        "[FAILED] IAM validation failed."
    )

    return 1


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("IAM VALIDATION")

    info(
        f"Project: {PROJECT_NAME}"
    )

    info(
        f"Environment: {ENVIRONMENT}"
    )

    info(
        f"AWS Region: {AWS_REGION}"
    )

    info(
        "LocalStack endpoint: "
        f"{LOCALSTACK_ENDPOINT}"
    )

    info(
        f"Expected role: "
        f"{EXPECTED_ROLE_NAME}"
    )

    info(
        "Expected instance profile: "
        f"{EXPECTED_INSTANCE_PROFILE_NAME}"
    )

    info(
        f"SSM enabled: "
        f"{IAM_ENABLE_SSM}"
    )

    info(
        "CloudWatch Agent enabled: "
        f"{IAM_ENABLE_CLOUDWATCH_AGENT}"
    )

    try:
        iam = get_iam_client()

        # ----------------------------------------------------
        # Role
        # ----------------------------------------------------

        role = get_role(iam)

        if role is None:
            failed(
                "EC2 IAM role not found: "
                f"{EXPECTED_ROLE_NAME}"
            )
            return print_summary()

        validate_role(
            iam,
            role,
        )

        validate_trust_policy(
            role
        )

        # ----------------------------------------------------
        # Instance Profile
        # ----------------------------------------------------

        profile = get_instance_profile(
            iam
        )

        if profile is None:
            failed(
                "EC2 instance profile "
                "not found: "
                f"{EXPECTED_INSTANCE_PROFILE_NAME}"
            )
        else:
            validate_instance_profile(
                iam,
                profile,
            )

        # ----------------------------------------------------
        # Inline Policies
        # ----------------------------------------------------

        validate_inline_policies(
            iam
        )

        # ----------------------------------------------------
        # Managed Policies
        # ----------------------------------------------------

        local_policies = (
            list_local_policies(
                iam
            )
        )

        attached_policies = (
            get_attached_policies(
                iam
            )
        )

        policies_by_name = {
            policy.get(
                "PolicyName"
            ): policy
            for policy in local_policies
            if policy.get(
                "PolicyName"
            )
        }

        attached_by_name = {
            policy.get(
                "PolicyName"
            ): policy
            for policy in attached_policies
            if policy.get(
                "PolicyName"
            )
        }

        validate_managed_policy(
            iam=iam,
            policies_by_name=(
                policies_by_name
            ),
            attached_by_name=(
                attached_by_name
            ),
            policy_name=(
                EXPECTED_SSM_POLICY_NAME
            ),
            required_actions=(
                REQUIRED_SSM_ACTIONS
            ),
            enabled=IAM_ENABLE_SSM,
            label="SSM",
        )

        validate_managed_policy(
            iam=iam,
            policies_by_name=(
                policies_by_name
            ),
            attached_by_name=(
                attached_by_name
            ),
            policy_name=(
                EXPECTED_CLOUDWATCH_AGENT_POLICY_NAME
            ),
            required_actions=(
                REQUIRED_CLOUDWATCH_ACTIONS
            ),
            enabled=(
                IAM_ENABLE_CLOUDWATCH_AGENT
            ),
            label="CloudWatch Agent",
        )

        validate_policy_attachments(
            attached_policies
        )

        # ----------------------------------------------------
        # Project Resource Counts
        # ----------------------------------------------------

        validate_project_resources(
            iam,
            local_policies,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        failed(
            "AWS/LocalStack IAM API "
            f"error: {exc}"
        )

    except Exception as exc:

        failed(
            "Unexpected IAM validation "
            f"error: "
            f"{type(exc).__name__}: "
            f"{exc}"
        )

    return print_summary()


if __name__ == "__main__":
    sys.exit(main())