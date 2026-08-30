import json
import os
import re

import boto3
import pytest
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
    '{"ENVIRONMENT":"localstack","LOG_LEVEL":"INFO"}',
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
# Runtime Test
# ============================================================

LAMBDA_INVOCATION_PAYLOAD_JSON = os.getenv(
    "LAMBDA_INVOCATION_PAYLOAD_JSON",
    '{"order_id":"pytest-order-001","source":"pytest"}',
)

LAMBDA_EXPECTED_RESPONSE_JSON = os.getenv(
    "LAMBDA_EXPECTED_RESPONSE_JSON",
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
        pytest.fail(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        )

    if not isinstance(
        value,
        dict,
    ):
        pytest.fail(
            f"{variable_name} must contain "
            "a JSON object."
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
        pytest.fail(
            f"{variable_name} contains invalid JSON: "
            f"{error}"
        )

    if not isinstance(
        value,
        list,
    ):
        pytest.fail(
            f"{variable_name} must contain "
            "a JSON array."
        )

    return value


def normalize_json(
    value,
):
    if isinstance(
        value,
        str,
    ):
        try:
            value = json.loads(
                value
            )

        except json.JSONDecodeError as error:
            pytest.fail(
                f"Unable to normalize JSON: {error}"
            )

    return json.dumps(
        value,
        sort_keys=True,
        separators=(
            ",",
            ":",
        ),
    )


# ============================================================
# Client
# ============================================================

@pytest.fixture(
    scope="session"
)
def lambda_client():
    return boto3.client(
        "lambda",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# Lambda Configuration
# ============================================================

@pytest.fixture(
    scope="session"
)
def function_configuration(
    lambda_client,
):
    try:
        return lambda_client.get_function_configuration(
            FunctionName=EXPECTED_FUNCTION_NAME,
        )

    except ClientError as error:
        pytest.fail(
            "Unable to get Lambda function "
            f"{EXPECTED_FUNCTION_NAME}: {error}"
        )

    except BotoCoreError as error:
        pytest.fail(
            "Lambda SDK error while reading "
            f"function configuration: {error}"
        )


@pytest.fixture(
    scope="session"
)
def function_arn(
    function_configuration,
):
    arn = function_configuration.get(
        "FunctionArn"
    )

    assert arn, (
        "Lambda FunctionArn is missing."
    )

    return arn


@pytest.fixture(
    scope="session"
)
def function_tags(
    lambda_client,
    function_arn,
):
    response = lambda_client.list_tags(
        Resource=function_arn,
    )

    return response.get(
        "Tags",
        {},
    )


@pytest.fixture(
    scope="session"
)
def function_concurrency(
    lambda_client,
):
    try:
        response = (
            lambda_client
            .get_function_concurrency(
                FunctionName=EXPECTED_FUNCTION_NAME,
            )
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

        if error_code in {
            "ResourceNotFoundException",
            "ResourceNotFound",
        }:
            return None

        raise


# ============================================================
# API Tests
# ============================================================

def test_lambda_api_available(
    lambda_client,
):
    response = lambda_client.list_functions(
        MaxItems=1,
    )

    status_code = response.get(
        "ResponseMetadata",
        {},
    ).get(
        "HTTPStatusCode"
    )

    assert status_code == 200


def test_lambda_function_exists(
    function_configuration,
):
    assert (
        function_configuration.get(
            "FunctionName"
        )
        == EXPECTED_FUNCTION_NAME
    )


# ============================================================
# Identity
# ============================================================

def test_function_name(
    function_configuration,
):
    assert (
        function_configuration.get(
            "FunctionName"
        )
        == EXPECTED_FUNCTION_NAME
    )


def test_function_arn_format(
    function_arn,
):
    pattern = re.compile(
        r"^arn:[^:]+:"
        r"lambda:"
        r"[^:]+:"
        r"[0-9]{12}:"
        r"function:"
        r".+$"
    )

    assert pattern.match(
        function_arn
    ), (
        "Invalid Lambda ARN: "
        f"{function_arn}"
    )


def test_function_region(
    function_arn,
):
    arn_parts = function_arn.split(
        ":",
        6,
    )

    assert len(
        arn_parts
    ) >= 7

    assert (
        arn_parts[3]
        == AWS_REGION
    )


# ============================================================
# Function State
# ============================================================

def test_function_state(
    function_configuration,
):
    state = function_configuration.get(
        "State"
    )

    # Some LocalStack versions may omit this field.
    if state is None:
        pytest.skip(
            "Lambda State is not returned "
            "by this emulator implementation."
        )

    assert state == "Active"


def test_last_update_status(
    function_configuration,
):
    status = function_configuration.get(
        "LastUpdateStatus"
    )

    if status is None:
        pytest.skip(
            "Lambda LastUpdateStatus is not "
            "returned by this emulator."
        )

    assert status == "Successful"


# ============================================================
# Package
# ============================================================

def test_package_type(
    function_configuration,
):
    assert (
        function_configuration.get(
            "PackageType",
            "Zip",
        )
        == "Zip"
    )


# ============================================================
# Runtime / Handler
# ============================================================

def test_runtime(
    function_configuration,
):
    assert (
        function_configuration.get(
            "Runtime"
        )
        == LAMBDA_RUNTIME
    )


def test_handler(
    function_configuration,
):
    assert (
        function_configuration.get(
            "Handler"
        )
        == LAMBDA_HANDLER
    )


# ============================================================
# IAM
# ============================================================

def test_execution_role_exists(
    function_configuration,
):
    role_arn = function_configuration.get(
        "Role"
    )

    assert role_arn


def test_execution_role_arn_format(
    function_configuration,
):
    role_arn = function_configuration.get(
        "Role"
    )

    assert role_arn

    pattern = re.compile(
        r"^arn:[^:]+:"
        r"iam::"
        r"[0-9]{12}:"
        r"role/.+$"
    )

    assert pattern.match(
        role_arn
    ), (
        "Invalid Lambda execution role ARN: "
        f"{role_arn}"
    )


def test_execution_role_matches_expected(
    function_configuration,
):
    if not LAMBDA_ROLE_ARN:
        pytest.skip(
            "LAMBDA_ROLE_ARN is not configured."
        )

    assert (
        function_configuration.get(
            "Role"
        )
        == LAMBDA_ROLE_ARN
    )


# ============================================================
# Architecture
# ============================================================

def test_architectures(
    function_configuration,
):
    expected = parse_json_list(
        LAMBDA_ARCHITECTURES_JSON,
        "LAMBDA_ARCHITECTURES_JSON",
    )

    actual = function_configuration.get(
        "Architectures",
        [],
    )

    assert actual == expected


# ============================================================
# Compute
# ============================================================

def test_memory_size(
    function_configuration,
):
    assert (
        function_configuration.get(
            "MemorySize"
        )
        == LAMBDA_MEMORY_SIZE
    )


def test_timeout(
    function_configuration,
):
    assert (
        function_configuration.get(
            "Timeout"
        )
        == LAMBDA_TIMEOUT
    )


def test_ephemeral_storage(
    function_configuration,
):
    ephemeral = function_configuration.get(
        "EphemeralStorage"
    )

    if ephemeral is None:
        if LAMBDA_EPHEMERAL_STORAGE_SIZE == 512:
            pytest.skip(
                "EphemeralStorage omitted by API; "
                "expected value is default 512 MB."
            )

        pytest.fail(
            "EphemeralStorage is missing but "
            f"{LAMBDA_EPHEMERAL_STORAGE_SIZE} MB "
            "was expected."
        )

    assert (
        ephemeral.get(
            "Size"
        )
        == LAMBDA_EPHEMERAL_STORAGE_SIZE
    )


# ============================================================
# Description
# ============================================================

def test_description(
    function_configuration,
):
    if LAMBDA_DESCRIPTION is None:
        pytest.skip(
            "LAMBDA_DESCRIPTION is not configured."
        )

    assert (
        function_configuration.get(
            "Description",
            "",
        )
        == LAMBDA_DESCRIPTION
    )


# ============================================================
# Environment Variables
# ============================================================

def test_environment_variables(
    function_configuration,
):
    expected = parse_json_object(
        LAMBDA_ENVIRONMENT_VARIABLES_JSON,
        "LAMBDA_ENVIRONMENT_VARIABLES_JSON",
    )

    environment = function_configuration.get(
        "Environment",
        {},
    )

    actual = environment.get(
        "Variables",
        {},
    )

    for (
        key,
        expected_value
    ) in expected.items():

        assert key in actual, (
            f"Required Lambda environment "
            f"variable missing: {key}"
        )

        assert (
            actual[key]
            == expected_value
        ), (
            f"Environment variable {key}: "
            f"expected {expected_value!r}, "
            f"got {actual[key]!r}"
        )


# ============================================================
# KMS
# ============================================================

def test_kms_configuration(
    function_configuration,
):
    actual = function_configuration.get(
        "KMSKeyArn"
    )

    if LAMBDA_KMS_KEY_ARN:
        assert (
            actual
            == LAMBDA_KMS_KEY_ARN
        )

    else:
        assert not actual


# ============================================================
# X-Ray
# ============================================================

def test_tracing_mode(
    function_configuration,
):
    tracing = function_configuration.get(
        "TracingConfig",
        {},
    )

    actual = tracing.get(
        "Mode",
        "PassThrough",
    )

    assert (
        actual
        == LAMBDA_TRACING_MODE
    )


# ============================================================
# Reserved Concurrency
# ============================================================

def test_reserved_concurrency(
    function_concurrency,
):
    if (
        LAMBDA_RESERVED_CONCURRENT_EXECUTIONS
        == -1
    ):
        assert function_concurrency is None

    else:
        assert (
            function_concurrency
            ==
            LAMBDA_RESERVED_CONCURRENT_EXECUTIONS
        )


# ============================================================
# Layers
# ============================================================

def test_layers(
    function_configuration,
):
    expected = parse_json_list(
        LAMBDA_LAYERS_JSON,
        "LAMBDA_LAYERS_JSON",
    )

    actual = [
        layer.get(
            "Arn"
        )
        for layer in function_configuration.get(
            "Layers",
            [],
        )
        if layer.get(
            "Arn"
        )
    ]

    assert actual == expected


# ============================================================
# Code
# ============================================================

def test_code_size(
    function_configuration,
):
    code_size = function_configuration.get(
        "CodeSize"
    )

    assert isinstance(
        code_size,
        int,
    )

    assert code_size > 0


def test_code_sha256_exists(
    function_configuration,
):
    code_hash = function_configuration.get(
        "CodeSha256"
    )

    assert code_hash


def test_code_sha256_matches_expected(
    function_configuration,
):
    if not LAMBDA_SOURCE_CODE_HASH:
        pytest.skip(
            "LAMBDA_SOURCE_CODE_HASH "
            "is not configured."
        )

    assert (
        function_configuration.get(
            "CodeSha256"
        )
        == LAMBDA_SOURCE_CODE_HASH
    )


# ============================================================
# Tags
# ============================================================

def test_function_has_tags(
    function_tags,
):
    assert function_tags


@pytest.mark.parametrize(
    (
        "tag_key",
        "expected_value",
    ),
    EXPECTED_TAGS.items(),
)
def test_required_tags(
    function_tags,
    tag_key,
    expected_value,
):
    assert (
        function_tags.get(
            tag_key
        )
        == expected_value
    )


# ============================================================
# Runtime Invocation Fixture
# ============================================================

@pytest.fixture(
    scope="session"
)
def invocation_result(
    lambda_client,
):
    payload = parse_json_object(
        LAMBDA_INVOCATION_PAYLOAD_JSON,
        "LAMBDA_INVOCATION_PAYLOAD_JSON",
    )

    try:
        response = lambda_client.invoke(
            FunctionName=EXPECTED_FUNCTION_NAME,
            InvocationType="RequestResponse",
            Payload=json.dumps(
                payload
            ).encode(
                "utf-8"
            ),
        )

    except ClientError as error:
        pytest.fail(
            "Lambda invocation failed with "
            f"AWS API error: {error}"
        )

    except BotoCoreError as error:
        pytest.fail(
            "Lambda invocation failed with "
            f"SDK error: {error}"
        )

    payload_stream = response.get(
        "Payload"
    )

    assert payload_stream is not None, (
        "Lambda invoke response "
        "does not contain Payload."
    )

    raw_payload = payload_stream.read()

    if isinstance(
        raw_payload,
        bytes,
    ):
        raw_payload = raw_payload.decode(
            "utf-8"
        )

    return {
        "response": response,
        "raw_payload": raw_payload,
        "input": payload,
    }


# ============================================================
# Runtime - HTTP
# ============================================================

def test_invoke_http_status(
    invocation_result,
):
    response = invocation_result[
        "response"
    ]

    status_code = response.get(
        "StatusCode"
    )

    assert (
        status_code
        == 200
    ), (
        "Lambda invoke StatusCode expected "
        f"200, got {status_code}"
    )


# ============================================================
# Runtime - Function Error
# ============================================================

def test_invoke_has_no_function_error(
    invocation_result,
):
    response = invocation_result[
        "response"
    ]

    function_error = response.get(
        "FunctionError"
    )

    raw_payload = invocation_result[
        "raw_payload"
    ]

    assert not function_error, (
        "Lambda returned FunctionError="
        f"{function_error}. "
        f"Payload={raw_payload}"
    )


# ============================================================
# Runtime - Payload
# ============================================================

def test_invoke_payload_not_empty(
    invocation_result,
):
    raw_payload = invocation_result[
        "raw_payload"
    ]

    assert raw_payload is not None
    assert raw_payload.strip()


def test_invoke_payload_is_valid_json(
    invocation_result,
):
    raw_payload = invocation_result[
        "raw_payload"
    ]

    try:
        parsed = json.loads(
            raw_payload
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "Lambda response Payload "
            f"is not valid JSON: {error}. "
            f"Payload={raw_payload!r}"
        )

    assert parsed is not None


# ============================================================
# Runtime - Strict Response
# ============================================================

def test_invoke_response_matches_expected(
    invocation_result,
):
    if not LAMBDA_EXPECTED_RESPONSE_JSON:
        pytest.skip(
            "LAMBDA_EXPECTED_RESPONSE_JSON "
            "is not configured."
        )

    raw_payload = invocation_result[
        "raw_payload"
    ]

    try:
        expected_response = json.loads(
            LAMBDA_EXPECTED_RESPONSE_JSON
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "LAMBDA_EXPECTED_RESPONSE_JSON "
            f"is invalid: {error}"
        )

    try:
        actual_response = json.loads(
            raw_payload
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "Lambda response Payload "
            f"is invalid JSON: {error}"
        )

    assert (
        normalize_json(
            actual_response
        )
        ==
        normalize_json(
            expected_response
        )
    )


# ============================================================
# Runtime - Response Metadata
# ============================================================

def test_invoke_response_metadata(
    invocation_result,
):
    response = invocation_result[
        "response"
    ]

    metadata = response.get(
        "ResponseMetadata",
        {},
    )

    assert (
        metadata.get(
            "HTTPStatusCode"
        )
        == 200
    )