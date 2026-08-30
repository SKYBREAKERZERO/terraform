import json
import os
import re
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


# ============================================================
# Environment
# ============================================================

LOCALSTACK_ENDPOINT = os.getenv(
    "LOCALSTACK_ENDPOINT",
    "http://localhost:4566",
)

AWS_REGION = os.getenv(
    "AWS_REGION",
    "ap-northeast-1",
)

PROJECT_NAME = os.getenv(
    "PROJECT_NAME",
    "aws-enterprise-lab",
)

ENVIRONMENT = os.getenv(
    "ENVIRONMENT",
    "localstack",
)


# ============================================================
# Lambda - Expected Configuration
# ============================================================

LAMBDA_FUNCTION_NAME = os.getenv(
    "LAMBDA_FUNCTION_NAME",
)

LAMBDA_DESCRIPTION = os.getenv(
    "LAMBDA_DESCRIPTION",
)

LAMBDA_ROLE_ARN = os.getenv(
    "LAMBDA_ROLE_ARN",
)

LAMBDA_RUNTIME = os.getenv(
    "LAMBDA_RUNTIME",
    "python3.13",
)

LAMBDA_HANDLER = os.getenv(
    "LAMBDA_HANDLER",
    "lambda_function.lambda_handler",
)

LAMBDA_ARCHITECTURES_JSON = os.getenv(
    "LAMBDA_ARCHITECTURES_JSON",
    '["x86_64"]',
)

LAMBDA_MEMORY_SIZE = int(
    os.getenv(
        "LAMBDA_MEMORY_SIZE",
        "128",
    )
)

LAMBDA_TIMEOUT = int(
    os.getenv(
        "LAMBDA_TIMEOUT",
        "30",
    )
)

LAMBDA_EPHEMERAL_STORAGE_SIZE = int(
    os.getenv(
        "LAMBDA_EPHEMERAL_STORAGE_SIZE",
        "512",
    )
)

LAMBDA_ENVIRONMENT_VARIABLES_JSON = os.getenv(
    "LAMBDA_ENVIRONMENT_VARIABLES_JSON",
    json.dumps(
        {
            "ENVIRONMENT": "localstack",
            "LOG_LEVEL": "INFO",
        }
    ),
)

LAMBDA_KMS_KEY_ARN = os.getenv(
    "LAMBDA_KMS_KEY_ARN",
)

LAMBDA_TRACING_MODE = os.getenv(
    "LAMBDA_TRACING_MODE",
    "PassThrough",
)

LAMBDA_RESERVED_CONCURRENT_EXECUTIONS = int(
    os.getenv(
        "LAMBDA_RESERVED_CONCURRENT_EXECUTIONS",
        "-1",
    )
)

LAMBDA_LAYERS_JSON = os.getenv(
    "LAMBDA_LAYERS_JSON",
    "[]",
)

LAMBDA_SOURCE_CODE_HASH = os.getenv(
    "LAMBDA_SOURCE_CODE_HASH",
)


# ============================================================
# Expected Identity
# ============================================================

EXPECTED_FUNCTION_NAME = (
    LAMBDA_FUNCTION_NAME
    if LAMBDA_FUNCTION_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-function"
)

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_FUNCTION_NAME,
    "Component": "compute",
    "Service": "lambda",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(message):
    global PASS_COUNT

    PASS_COUNT += 1

    print(
        f"[PASS] {message}"
    )


def warn_check(message):
    global WARN_COUNT

    WARN_COUNT += 1

    print(
        f"[WARN] {message}"
    )


def fail_check(message):
    global FAIL_COUNT

    FAIL_COUNT += 1

    print(
        f"[FAIL] {message}"
    )


# ============================================================
# Client
# ============================================================

def create_lambda_client():
    return boto3.client(
        "lambda",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# JSON Helpers
# ============================================================

def parse_json_object(
    raw_value,
    variable_name,
):
    try:
        value = json.loads(
            raw_value
        )

    except json.JSONDecodeError as error:
        raise ValueError(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        ) from error

    if not isinstance(
        value,
        dict,
    ):
        raise ValueError(
            f"{variable_name} must contain a JSON object."
        )

    return value


def parse_json_list(
    raw_value,
    variable_name,
):
    try:
        value = json.loads(
            raw_value
        )

    except json.JSONDecodeError as error:
        raise ValueError(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        ) from error

    if not isinstance(
        value,
        list,
    ):
        raise ValueError(
            f"{variable_name} must contain a JSON array."
        )

    return value


# ============================================================
# Lambda Discovery
# ============================================================

def get_function_configuration(
    client,
):
    try:
        return client.get_function_configuration(
            FunctionName=EXPECTED_FUNCTION_NAME,
        )

    except ClientError as error:
        error_code = (
            error.response
            .get(
                "Error",
                {},
            )
            .get(
                "Code"
            )
        )

        if error_code in {
            "ResourceNotFoundException",
            "ResourceNotFound",
        }:
            return None

        raise


def get_function_tags(
    client,
    function_arn,
):
    if not function_arn:
        return {}

    response = client.list_tags(
        Resource=function_arn,
    )

    return response.get(
        "Tags",
        {},
    )


def get_function_concurrency(
    client,
):
    try:
        response = client.get_function_concurrency(
            FunctionName=EXPECTED_FUNCTION_NAME,
        )

        return response.get(
            "ReservedConcurrentExecutions"
        )

    except ClientError as error:
        error_code = (
            error.response
            .get(
                "Error",
                {},
            )
            .get(
                "Code"
            )
        )

        # No reserved concurrency configured.
        if error_code in {
            "ResourceNotFoundException",
            "ResourceNotFound",
        }:
            return None

        raise


# ============================================================
# Exists
# ============================================================

def validate_function_exists(
    configuration,
):
    if configuration is None:
        fail_check(
            "Lambda function not found: "
            f"{EXPECTED_FUNCTION_NAME}"
        )

        return False

    pass_check(
        "Lambda function exists: "
        f"{EXPECTED_FUNCTION_NAME}"
    )

    return True


# ============================================================
# Identity
# ============================================================

def validate_identity(
    configuration,
):
    actual_name = configuration.get(
        "FunctionName"
    )

    if actual_name == EXPECTED_FUNCTION_NAME:
        pass_check(
            "Lambda function name is correct: "
            f"{actual_name}"
        )
    else:
        fail_check(
            "Lambda function name expected "
            f"{EXPECTED_FUNCTION_NAME}, "
            f"got {actual_name}"
        )

    function_arn = configuration.get(
        "FunctionArn"
    )

    if not function_arn:
        fail_check(
            "Lambda function ARN is missing."
        )

        return

    arn_pattern = re.compile(
        r"^arn:[^:]+:"
        r"lambda:"
        r"[^:]+:"
        r"[0-9]{12}:"
        r"function:"
        r".+$"
    )

    if arn_pattern.match(
        function_arn
    ):
        pass_check(
            "Lambda function ARN format is valid."
        )
    else:
        fail_check(
            "Invalid Lambda function ARN: "
            f"{function_arn}"
        )

    arn_parts = function_arn.split(
        ":",
        6,
    )

    if (
        len(arn_parts) >= 7
        and arn_parts[3] == AWS_REGION
    ):
        pass_check(
            "Lambda function ARN region is correct: "
            f"{AWS_REGION}"
        )
    else:
        fail_check(
            "Lambda function ARN region "
            f"does not match {AWS_REGION}."
        )


# ============================================================
# State
# ============================================================

def validate_state(
    configuration,
):
    state = configuration.get(
        "State"
    )

    # Some emulators may omit State on older implementations.
    if state is None:
        warn_check(
            "Lambda State was not returned by the API."
        )

    elif state == "Active":
        pass_check(
            "Lambda function state is Active."
        )

    else:
        fail_check(
            "Lambda function state expected Active, "
            f"got {state}"
        )

    update_status = configuration.get(
        "LastUpdateStatus"
    )

    if update_status is None:
        warn_check(
            "Lambda LastUpdateStatus was not returned "
            "by the API."
        )

    elif update_status == "Successful":
        pass_check(
            "Lambda LastUpdateStatus is Successful."
        )

    else:
        fail_check(
            "Lambda LastUpdateStatus expected "
            f"Successful, got {update_status}"
        )


# ============================================================
# Package Type
# ============================================================

def validate_package_type(
    configuration,
):
    package_type = configuration.get(
        "PackageType",
        "Zip",
    )

    if package_type == "Zip":
        pass_check(
            "Lambda package type is Zip."
        )
    else:
        fail_check(
            "Lambda package type expected Zip, "
            f"got {package_type}"
        )


# ============================================================
# Runtime / Handler
# ============================================================

def validate_runtime(
    configuration,
):
    actual_runtime = configuration.get(
        "Runtime"
    )

    if actual_runtime == LAMBDA_RUNTIME:
        pass_check(
            "Lambda runtime matches expected value: "
            f"{actual_runtime}"
        )
    else:
        fail_check(
            "Lambda runtime expected "
            f"{LAMBDA_RUNTIME}, "
            f"got {actual_runtime}"
        )

    actual_handler = configuration.get(
        "Handler"
    )

    if actual_handler == LAMBDA_HANDLER:
        pass_check(
            "Lambda handler matches expected value: "
            f"{actual_handler}"
        )
    else:
        fail_check(
            "Lambda handler expected "
            f"{LAMBDA_HANDLER}, "
            f"got {actual_handler}"
        )


# ============================================================
# IAM Role
# ============================================================

def validate_role(
    configuration,
):
    actual_role = configuration.get(
        "Role"
    )

    if not actual_role:
        fail_check(
            "Lambda execution role ARN is missing."
        )

        return

    role_pattern = re.compile(
        r"^arn:[^:]+:"
        r"iam::"
        r"[0-9]{12}:"
        r"role/.+$"
    )

    if role_pattern.match(
        actual_role
    ):
        pass_check(
            "Lambda execution role ARN format is valid."
        )
    else:
        fail_check(
            "Invalid Lambda execution role ARN: "
            f"{actual_role}"
        )

    if LAMBDA_ROLE_ARN:
        if actual_role == LAMBDA_ROLE_ARN:
            pass_check(
                "Lambda execution role matches "
                "expected ARN."
            )
        else:
            fail_check(
                "Lambda execution role expected "
                f"{LAMBDA_ROLE_ARN}, "
                f"got {actual_role}"
            )
    else:
        warn_check(
            "LAMBDA_ROLE_ARN is not configured; "
            "strict IAM role comparison skipped."
        )


# ============================================================
# Architectures
# ============================================================

def validate_architectures(
    configuration,
):
    expected = parse_json_list(
        LAMBDA_ARCHITECTURES_JSON,
        "LAMBDA_ARCHITECTURES_JSON",
    )

    actual = configuration.get(
        "Architectures",
        [],
    )

    if actual == expected:
        pass_check(
            "Lambda architecture matches expected value: "
            f"{actual}"
        )
    else:
        fail_check(
            "Lambda architectures expected "
            f"{expected}, "
            f"got {actual}"
        )


# ============================================================
# Compute
# ============================================================

def validate_compute(
    configuration,
):
    actual_memory = configuration.get(
        "MemorySize"
    )

    if actual_memory == LAMBDA_MEMORY_SIZE:
        pass_check(
            "Lambda memory size matches expected value: "
            f"{actual_memory} MB"
        )
    else:
        fail_check(
            "Lambda memory size expected "
            f"{LAMBDA_MEMORY_SIZE} MB, "
            f"got {actual_memory}"
        )

    actual_timeout = configuration.get(
        "Timeout"
    )

    if actual_timeout == LAMBDA_TIMEOUT:
        pass_check(
            "Lambda timeout matches expected value: "
            f"{actual_timeout} seconds"
        )
    else:
        fail_check(
            "Lambda timeout expected "
            f"{LAMBDA_TIMEOUT} seconds, "
            f"got {actual_timeout}"
        )

    ephemeral_storage = configuration.get(
        "EphemeralStorage",
        {},
    )

    actual_ephemeral_size = (
        ephemeral_storage.get(
            "Size"
        )
    )

    if actual_ephemeral_size is None:
        # 512 MB is the Lambda default and some emulators
        # may omit EphemeralStorage from the response.
        if LAMBDA_EPHEMERAL_STORAGE_SIZE == 512:
            warn_check(
                "EphemeralStorage was not returned; "
                "expected value is the default 512 MB."
            )
        else:
            fail_check(
                "EphemeralStorage was not returned "
                f"but expected "
                f"{LAMBDA_EPHEMERAL_STORAGE_SIZE} MB."
            )

    elif (
        actual_ephemeral_size
        == LAMBDA_EPHEMERAL_STORAGE_SIZE
    ):
        pass_check(
            "Lambda ephemeral storage matches "
            f"expected value: "
            f"{actual_ephemeral_size} MB"
        )

    else:
        fail_check(
            "Lambda ephemeral storage expected "
            f"{LAMBDA_EPHEMERAL_STORAGE_SIZE} MB, "
            f"got {actual_ephemeral_size}"
        )


# ============================================================
# Environment Variables
# ============================================================

def validate_environment_variables(
    configuration,
):
    expected_variables = parse_json_object(
        LAMBDA_ENVIRONMENT_VARIABLES_JSON,
        "LAMBDA_ENVIRONMENT_VARIABLES_JSON",
    )

    environment = configuration.get(
        "Environment",
        {},
    )

    actual_variables = environment.get(
        "Variables",
        {},
    )

    if not expected_variables:
        if not actual_variables:
            pass_check(
                "No Lambda environment variables "
                "are expected or configured."
            )
        else:
            warn_check(
                "Lambda has environment variables, "
                "but no strict expected variables "
                "were configured."
            )

        return

    for (
        key,
        expected_value
    ) in expected_variables.items():

        actual_value = actual_variables.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                "Environment variable "
                f"{key} matches expected value."
            )
        elif actual_value is None:
            fail_check(
                "Required Lambda environment "
                f"variable missing: {key}"
            )
        else:
            fail_check(
                "Environment variable "
                f"{key} expected "
                f"{expected_value}, "
                f"got {actual_value}"
            )


# ============================================================
# KMS
# ============================================================

def validate_kms(
    configuration,
):
    actual_kms_key = configuration.get(
        "KMSKeyArn"
    )

    if LAMBDA_KMS_KEY_ARN:
        if actual_kms_key == LAMBDA_KMS_KEY_ARN:
            pass_check(
                "Lambda KMS key matches expected ARN."
            )
        else:
            fail_check(
                "Lambda KMS key expected "
                f"{LAMBDA_KMS_KEY_ARN}, "
                f"got {actual_kms_key}"
            )

    else:
        if not actual_kms_key:
            pass_check(
                "No customer-managed KMS key "
                "is configured."
            )
        else:
            fail_check(
                "Lambda has a KMS key configured "
                "although LAMBDA_KMS_KEY_ARN is unset: "
                f"{actual_kms_key}"
            )


# ============================================================
# X-Ray
# ============================================================

def validate_tracing(
    configuration,
):
    tracing_config = configuration.get(
        "TracingConfig",
        {},
    )

    actual_mode = tracing_config.get(
        "Mode",
        "PassThrough",
    )

    if actual_mode == LAMBDA_TRACING_MODE:
        pass_check(
            "Lambda X-Ray tracing mode matches "
            f"expected value: {actual_mode}"
        )
    else:
        fail_check(
            "Lambda tracing mode expected "
            f"{LAMBDA_TRACING_MODE}, "
            f"got {actual_mode}"
        )


# ============================================================
# Reserved Concurrency
# ============================================================

def validate_concurrency(
    actual_concurrency,
):
    if (
        LAMBDA_RESERVED_CONCURRENT_EXECUTIONS
        == -1
    ):
        if actual_concurrency is None:
            pass_check(
                "Lambda reserved concurrency "
                "is unreserved."
            )
        else:
            fail_check(
                "Lambda reserved concurrency expected "
                "unreserved, "
                f"got {actual_concurrency}"
            )

        return

    if (
        actual_concurrency
        == LAMBDA_RESERVED_CONCURRENT_EXECUTIONS
    ):
        pass_check(
            "Lambda reserved concurrency matches "
            "expected value: "
            f"{actual_concurrency}"
        )
    else:
        fail_check(
            "Lambda reserved concurrency expected "
            f"{LAMBDA_RESERVED_CONCURRENT_EXECUTIONS}, "
            f"got {actual_concurrency}"
        )


# ============================================================
# Layers
# ============================================================

def validate_layers(
    configuration,
):
    expected_layers = parse_json_list(
        LAMBDA_LAYERS_JSON,
        "LAMBDA_LAYERS_JSON",
    )

    actual_layers = [
        layer.get(
            "Arn"
        )
        for layer in configuration.get(
            "Layers",
            [],
        )
        if layer.get(
            "Arn"
        )
    ]

    if not expected_layers:
        if not actual_layers:
            pass_check(
                "No Lambda layers are configured."
            )
        else:
            fail_check(
                "No Lambda layers were expected, "
                f"got {actual_layers}"
            )

        return

    if actual_layers == expected_layers:
        pass_check(
            "Lambda layers match expected configuration."
        )
    else:
        fail_check(
            "Lambda layers expected "
            f"{expected_layers}, "
            f"got {actual_layers}"
        )


# ============================================================
# Code
# ============================================================

def validate_code(
    configuration,
):
    code_size = configuration.get(
        "CodeSize"
    )

    if (
        isinstance(code_size, int)
        and code_size > 0
    ):
        pass_check(
            "Lambda deployment package has code: "
            f"{code_size} bytes"
        )
    else:
        fail_check(
            "Lambda deployment package CodeSize "
            f"is invalid: {code_size}"
        )

    actual_code_hash = configuration.get(
        "CodeSha256"
    )

    if actual_code_hash:
        pass_check(
            "Lambda CodeSha256 is present."
        )
    else:
        warn_check(
            "Lambda CodeSha256 was not returned."
        )

    if LAMBDA_SOURCE_CODE_HASH:
        if (
            actual_code_hash
            == LAMBDA_SOURCE_CODE_HASH
        ):
            pass_check(
                "Lambda CodeSha256 matches "
                "expected source code hash."
            )
        else:
            fail_check(
                "Lambda CodeSha256 does not match "
                "LAMBDA_SOURCE_CODE_HASH."
            )


# ============================================================
# Description
# ============================================================

def validate_description(
    configuration,
):
    if LAMBDA_DESCRIPTION is None:
        return

    actual_description = configuration.get(
        "Description",
        "",
    )

    if actual_description == LAMBDA_DESCRIPTION:
        pass_check(
            "Lambda description matches "
            "expected value."
        )
    else:
        fail_check(
            "Lambda description expected "
            f"{LAMBDA_DESCRIPTION!r}, "
            f"got {actual_description!r}"
        )


# ============================================================
# Tags
# ============================================================

def validate_tags(
    tags,
):
    if not tags:
        fail_check(
            "Lambda function has no tags."
        )

        return

    pass_check(
        "Lambda function has tags."
    )

    for (
        key,
        expected_value
    ) in EXPECTED_TAGS.items():

        actual_value = tags.get(
            key
        )

        if actual_value == expected_value:
            pass_check(
                f"Tag {key}={expected_value}"
            )

        elif actual_value is None:
            fail_check(
                f"Required Lambda tag missing: {key}"
            )

        else:
            fail_check(
                f"Tag {key} expected "
                f"{expected_value}, "
                f"got {actual_value}"
            )


# ============================================================
# Summary
# ============================================================

def print_summary():
    print()

    print(
        "=" * 70
    )

    print(
        "LAMBDA VALIDATION SUMMARY"
    )

    print(
        "=" * 70
    )

    print(
        f"PASS: {PASS_COUNT}"
    )

    print(
        f"WARN: {WARN_COUNT}"
    )

    print(
        f"FAIL: {FAIL_COUNT}"
    )


# ============================================================
# Run
# ============================================================

def run():
    client = create_lambda_client()

    configuration = (
        get_function_configuration(
            client
        )
    )

    if not validate_function_exists(
        configuration
    ):
        return

    function_arn = configuration.get(
        "FunctionArn"
    )

    tags = get_function_tags(
        client,
        function_arn,
    )

    concurrency = get_function_concurrency(
        client
    )

    validate_identity(
        configuration
    )

    validate_state(
        configuration
    )

    validate_package_type(
        configuration
    )

    validate_runtime(
        configuration
    )

    validate_role(
        configuration
    )

    validate_architectures(
        configuration
    )

    validate_compute(
        configuration
    )

    validate_environment_variables(
        configuration
    )

    validate_kms(
        configuration
    )

    validate_tracing(
        configuration
    )

    validate_concurrency(
        concurrency
    )

    validate_layers(
        configuration
    )

    validate_code(
        configuration
    )

    validate_description(
        configuration
    )

    validate_tags(
        tags
    )


# ============================================================
# Main
# ============================================================

def main():
    try:
        run()

    except ClientError as error:
        error_info = error.response.get(
            "Error",
            {},
        )

        error_code = error_info.get(
            "Code",
            "Unknown",
        )

        error_message = error_info.get(
            "Message",
            str(error),
        )

        fail_check(
            "AWS API error: "
            f"{error_code}: "
            f"{error_message}"
        )

    except BotoCoreError as error:
        fail_check(
            f"AWS SDK error: {error}"
        )

    except (
        TypeError,
        ValueError,
    ) as error:
        fail_check(
            f"Configuration error: {error}"
        )

    except KeyboardInterrupt:
        print()
        print(
            "[INFO] Interrupted by user."
        )

        return 130

    print_summary()

    if FAIL_COUNT > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(
        main()
    )