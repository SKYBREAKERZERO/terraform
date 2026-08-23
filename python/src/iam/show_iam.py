from __future__ import annotations

import json
import sys
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

EXPECTED_ROLE_NAME = (
    f"{PROJECT_PREFIX}-ec2-role"
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
# Output Helpers
# ============================================================

def section(title: str) -> None:
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}")


def error(message: str) -> None:
    print(
        f"[ERROR] {message}",
        file=sys.stderr,
    )


def pretty(data: Any) -> None:
    print(
        json.dumps(
            data,
            indent=2,
            ensure_ascii=False,
            default=str,
        )
    )


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


def is_no_such_entity(
    exc: ClientError,
) -> bool:

    error_code = (
        exc.response
        .get("Error", {})
        .get("Code", "")
    )

    return error_code in {
        "NoSuchEntity",
        "NoSuchEntityException",
    }


# ============================================================
# IAM Role
# ============================================================

def get_ec2_role(
    iam: Any,
) -> dict[str, Any] | None:

    try:
        response = iam.get_role(
            RoleName=EXPECTED_ROLE_NAME
        )

        return response.get("Role")

    except ClientError as exc:

        if is_no_such_entity(exc):
            warn(
                "EC2 IAM role not found: "
                f"{EXPECTED_ROLE_NAME}"
            )
            return None

        raise


def show_role(
    role: dict[str, Any],
) -> None:

    section("EC2 IAM ROLE")

    pretty(
        {
            "RoleName": role.get("RoleName"),
            "RoleId": role.get("RoleId"),
            "Arn": role.get("Arn"),
            "Path": role.get("Path"),
            "Description": role.get(
                "Description"
            ),
            "CreateDate": role.get(
                "CreateDate"
            ),
            "MaxSessionDuration": role.get(
                "MaxSessionDuration"
            ),
        }
    )


# ============================================================
# Trust Policy
# ============================================================

def show_trust_policy(
    role: dict[str, Any],
) -> None:

    section("TRUST POLICY")

    trust_policy = role.get(
        "AssumeRolePolicyDocument"
    )

    if trust_policy:
        pretty(trust_policy)
    else:
        warn(
            "Trust policy document "
            "was not returned."
        )


# ============================================================
# Role Tags
# ============================================================

def show_role_tags(
    iam: Any,
) -> None:

    section("ROLE TAGS")

    try:
        response = iam.list_role_tags(
            RoleName=EXPECTED_ROLE_NAME
        )

        tags = tags_to_dict(
            response.get("Tags")
        )

        if tags:
            pretty(tags)
        else:
            info("No role tags configured.")

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "Unable to retrieve role tags: "
            f"{exc}"
        )


# ============================================================
# Attached Managed Policies
# ============================================================

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


def show_attached_policies(
    policies: list[dict[str, Any]],
) -> None:

    section("ATTACHED MANAGED POLICIES")

    if not policies:
        info(
            "No managed policies "
            "are attached."
        )
        return

    pretty(policies)


# ============================================================
# Inline Policies
# ============================================================

def get_inline_policy_names(
    iam: Any,
) -> list[str]:

    result: list[str] = []

    paginator = iam.get_paginator(
        "list_role_policies"
    )

    for page in paginator.paginate(
        RoleName=EXPECTED_ROLE_NAME
    ):
        result.extend(
            page.get(
                "PolicyNames",
                [],
            )
        )

    return result


def show_inline_policies(
    iam: Any,
    policy_names: list[str],
) -> None:

    section("INLINE POLICIES")

    if not policy_names:
        info(
            "No inline policies "
            "are configured."
        )
        return

    for policy_name in policy_names:

        print()
        info(
            f"Inline policy: "
            f"{policy_name}"
        )

        try:
            response = iam.get_role_policy(
                RoleName=EXPECTED_ROLE_NAME,
                PolicyName=policy_name,
            )

            pretty(
                {
                    "PolicyName":
                        response.get(
                            "PolicyName"
                        ),
                    "PolicyDocument":
                        response.get(
                            "PolicyDocument"
                        ),
                }
            )

        except (
            ClientError,
            BotoCoreError,
        ) as exc:

            warn(
                "Unable to retrieve "
                f"{policy_name}: {exc}"
            )


# ============================================================
# Managed Policy Metadata
# ============================================================

def get_managed_policy(
    iam: Any,
    policy_arn: str,
) -> dict[str, Any] | None:

    try:
        response = iam.get_policy(
            PolicyArn=policy_arn
        )

        return response.get("Policy")

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "Unable to retrieve policy "
            f"{policy_arn}: {exc}"
        )

        return None


def show_managed_policy_details(
    iam: Any,
    policies: list[dict[str, Any]],
) -> None:

    section("MANAGED POLICY DETAILS")

    if not policies:
        info(
            "No managed policy metadata "
            "to display."
        )
        return

    for attachment in policies:

        policy_arn = attachment.get(
            "PolicyArn"
        )

        if not policy_arn:
            continue

        print()
        info(
            f"Policy ARN: {policy_arn}"
        )

        policy = get_managed_policy(
            iam,
            policy_arn,
        )

        if not policy:
            continue

        pretty(
            {
                "PolicyName":
                    policy.get(
                        "PolicyName"
                    ),
                "PolicyId":
                    policy.get(
                        "PolicyId"
                    ),
                "Arn":
                    policy.get("Arn"),
                "Path":
                    policy.get("Path"),
                "Description":
                    policy.get(
                        "Description"
                    ),
                "DefaultVersionId":
                    policy.get(
                        "DefaultVersionId"
                    ),
                "AttachmentCount":
                    policy.get(
                        "AttachmentCount"
                    ),
                "IsAttachable":
                    policy.get(
                        "IsAttachable"
                    ),
                "CreateDate":
                    policy.get(
                        "CreateDate"
                    ),
                "UpdateDate":
                    policy.get(
                        "UpdateDate"
                    ),
            }
        )


# ============================================================
# Managed Policy Documents
# ============================================================

def get_policy_document(
    iam: Any,
    policy_arn: str,
) -> dict[str, Any] | None:

    policy = get_managed_policy(
        iam,
        policy_arn,
    )

    if not policy:
        return None

    version_id = policy.get(
        "DefaultVersionId"
    )

    if not version_id:
        warn(
            "DefaultVersionId missing: "
            f"{policy_arn}"
        )
        return None

    try:
        response = iam.get_policy_version(
            PolicyArn=policy_arn,
            VersionId=version_id,
        )

        return (
            response
            .get(
                "PolicyVersion",
                {},
            )
            .get("Document")
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "Unable to retrieve "
            "policy document "
            f"{policy_arn}: {exc}"
        )

        return None


def show_managed_policy_documents(
    iam: Any,
    policies: list[dict[str, Any]],
) -> None:

    section("MANAGED POLICY DOCUMENTS")

    if not policies:
        info(
            "No managed policy documents "
            "to display."
        )
        return

    for attachment in policies:

        policy_name = attachment.get(
            "PolicyName",
            "<unknown>",
        )

        policy_arn = attachment.get(
            "PolicyArn"
        )

        if not policy_arn:
            continue

        print()
        print("-" * 70)

        info(
            f"Policy: {policy_name}"
        )

        info(
            f"ARN: {policy_arn}"
        )

        print("-" * 70)

        document = get_policy_document(
            iam,
            policy_arn,
        )

        if document is None:
            warn(
                "Policy document "
                "unavailable."
            )
            continue

        pretty(document)


# ============================================================
# Local Managed Policies
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


def show_expected_policy_status(
    policies: list[dict[str, Any]],
) -> None:

    section("EXPECTED POLICY STATUS")

    policies_by_name = {
        policy.get("PolicyName"): policy
        for policy in policies
        if policy.get("PolicyName")
    }

    expected_names = [
        EXPECTED_SSM_POLICY_NAME,
        EXPECTED_CLOUDWATCH_AGENT_POLICY_NAME,
    ]

    for policy_name in expected_names:

        policy = policies_by_name.get(
            policy_name
        )

        if not policy:
            info(
                "Not present or disabled: "
                f"{policy_name}"
            )
            continue

        pretty(
            {
                "PolicyName":
                    policy.get(
                        "PolicyName"
                    ),
                "Arn":
                    policy.get(
                        "Arn"
                    ),
                "AttachmentCount":
                    policy.get(
                        "AttachmentCount"
                    ),
                "DefaultVersionId":
                    policy.get(
                        "DefaultVersionId"
                    ),
            }
        )


# ============================================================
# Instance Profile
# ============================================================

def get_instance_profile(
    iam: Any,
) -> dict[str, Any] | None:

    try:
        response = iam.get_instance_profile(
            InstanceProfileName=(
                EXPECTED_INSTANCE_PROFILE_NAME
            )
        )

        return response.get(
            "InstanceProfile"
        )

    except ClientError as exc:

        if is_no_such_entity(exc):
            warn(
                "Instance profile "
                "not found: "
                f"{EXPECTED_INSTANCE_PROFILE_NAME}"
            )
            return None

        raise


def show_instance_profile(
    profile: dict[str, Any],
) -> None:

    section("EC2 INSTANCE PROFILE")

    pretty(
        {
            "InstanceProfileName":
                profile.get(
                    "InstanceProfileName"
                ),
            "InstanceProfileId":
                profile.get(
                    "InstanceProfileId"
                ),
            "Arn":
                profile.get("Arn"),
            "Path":
                profile.get("Path"),
            "CreateDate":
                profile.get(
                    "CreateDate"
                ),
            "Tags":
                tags_to_dict(
                    profile.get("Tags")
                ),
        }
    )


def show_instance_profile_roles(
    profile: dict[str, Any],
) -> None:

    section("INSTANCE PROFILE ROLES")

    roles = profile.get(
        "Roles",
        [],
    )

    if not roles:
        warn(
            "No IAM role is associated "
            "with the instance profile."
        )
        return

    result = []

    for role in roles:
        result.append(
            {
                "RoleName":
                    role.get(
                        "RoleName"
                    ),
                "RoleId":
                    role.get(
                        "RoleId"
                    ),
                "Arn":
                    role.get("Arn"),
                "Path":
                    role.get("Path"),
            }
        )

    pretty(result)


# ============================================================
# Instance Profiles For Role
# ============================================================

def show_instance_profiles_for_role(
    iam: Any,
) -> None:

    section("INSTANCE PROFILES FOR ROLE")

    profiles: list[
        dict[str, Any]
    ] = []

    try:
        paginator = iam.get_paginator(
            "list_instance_profiles_for_role"
        )

        for page in paginator.paginate(
            RoleName=EXPECTED_ROLE_NAME
        ):
            profiles.extend(
                page.get(
                    "InstanceProfiles",
                    [],
                )
            )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        warn(
            "Unable to list profiles "
            f"for role: {exc}"
        )
        return

    if not profiles:
        warn(
            "No instance profile "
            "associated with role."
        )
        return

    result = []

    for profile in profiles:

        result.append(
            {
                "InstanceProfileName":
                    profile.get(
                        "InstanceProfileName"
                    ),
                "InstanceProfileId":
                    profile.get(
                        "InstanceProfileId"
                    ),
                "Arn":
                    profile.get("Arn"),
            }
        )

    pretty(result)


# ============================================================
# Project Resource Overview
# ============================================================

def list_roles(
    iam: Any,
) -> list[dict[str, Any]]:

    result: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_roles"
    )

    for page in paginator.paginate():
        result.extend(
            page.get(
                "Roles",
                [],
            )
        )

    return result


def list_instance_profiles(
    iam: Any,
) -> list[dict[str, Any]]:

    result: list[
        dict[str, Any]
    ] = []

    paginator = iam.get_paginator(
        "list_instance_profiles"
    )

    for page in paginator.paginate():
        result.extend(
            page.get(
                "InstanceProfiles",
                [],
            )
        )

    return result


def show_project_iam_overview(
    iam: Any,
    local_policies: list[
        dict[str, Any]
    ],
) -> None:

    section(
        "PROJECT IAM RESOURCE OVERVIEW"
    )

    roles = list_roles(iam)

    project_roles = [
        {
            "RoleName":
                role.get("RoleName"),
            "Arn":
                role.get("Arn"),
        }
        for role in roles
        if str(
            role.get(
                "RoleName",
                "",
            )
        ).startswith(
            PROJECT_PREFIX
        )
    ]

    project_policies = [
        {
            "PolicyName":
                policy.get(
                    "PolicyName"
                ),
            "Arn":
                policy.get("Arn"),
            "AttachmentCount":
                policy.get(
                    "AttachmentCount"
                ),
        }
        for policy in local_policies
        if str(
            policy.get(
                "PolicyName",
                "",
            )
        ).startswith(
            PROJECT_PREFIX
        )
    ]

    profiles = list_instance_profiles(
        iam
    )

    project_profiles = [
        {
            "InstanceProfileName":
                profile.get(
                    "InstanceProfileName"
                ),
            "Arn":
                profile.get("Arn"),
            "Roles": [
                role.get("RoleName")
                for role in profile.get(
                    "Roles",
                    [],
                )
            ],
        }
        for profile in profiles
        if str(
            profile.get(
                "InstanceProfileName",
                "",
            )
        ).startswith(
            PROJECT_PREFIX
        )
    ]

    info("Roles")
    pretty(project_roles)

    print()
    info("Managed Policies")
    pretty(project_policies)

    print()
    info("Instance Profiles")
    pretty(project_profiles)


# ============================================================
# Main
# ============================================================

def main() -> int:

    section("IAM INSPECTION")

    info(
        f"Project             : "
        f"{PROJECT_NAME}"
    )

    info(
        f"Environment         : "
        f"{ENVIRONMENT}"
    )

    info(
        f"AWS region          : "
        f"{AWS_REGION}"
    )

    info(
        f"LocalStack endpoint : "
        f"{LOCALSTACK_ENDPOINT}"
    )

    info(
        f"Expected role       : "
        f"{EXPECTED_ROLE_NAME}"
    )

    info(
        f"Expected profile    : "
        f"{EXPECTED_INSTANCE_PROFILE_NAME}"
    )

    try:
        iam = get_iam_client()

        # ----------------------------------------------------
        # Role
        # ----------------------------------------------------

        role = get_ec2_role(iam)

        if role is None:
            error(
                "Required EC2 IAM role "
                "is missing."
            )
            return 1

        show_role(role)
        show_trust_policy(role)
        show_role_tags(iam)

        # ----------------------------------------------------
        # Policies
        # ----------------------------------------------------

        attached_policies = (
            get_attached_policies(iam)
        )

        show_attached_policies(
            attached_policies
        )

        inline_policy_names = (
            get_inline_policy_names(iam)
        )

        show_inline_policies(
            iam,
            inline_policy_names,
        )

        show_managed_policy_details(
            iam,
            attached_policies,
        )

        show_managed_policy_documents(
            iam,
            attached_policies,
        )

        local_policies = (
            list_local_policies(iam)
        )

        show_expected_policy_status(
            local_policies
        )

        # ----------------------------------------------------
        # Instance Profile
        # ----------------------------------------------------

        profile = get_instance_profile(
            iam
        )

        if profile is not None:
            show_instance_profile(
                profile
            )

            show_instance_profile_roles(
                profile
            )

        show_instance_profiles_for_role(
            iam
        )

        # ----------------------------------------------------
        # Overview
        # ----------------------------------------------------

        show_project_iam_overview(
            iam,
            local_policies,
        )

    except (
        ClientError,
        BotoCoreError,
    ) as exc:

        error(
            f"IAM API error: {exc}"
        )
        return 1

    except Exception as exc:

        error(
            "Unexpected IAM inspection "
            f"error: "
            f"{type(exc).__name__}: "
            f"{exc}"
        )
        return 1

    section("IAM INSPECTION COMPLETE")

    print(
        "[SUCCESS] IAM inspection completed."
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())