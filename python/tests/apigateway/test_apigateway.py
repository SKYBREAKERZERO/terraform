import json
import os
import urllib.error
import urllib.request

import boto3
import pytest
from botocore.exceptions import (
    BotoCoreError,
    ClientError,
)


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

APIGATEWAY_ENABLED = (
    os.getenv(
        "APIGATEWAY_ENABLED",
        "true",
    ).lower()
    == "true"
)


# ============================================================
# Expected API Configuration
# ============================================================

APIGATEWAY_API_NAME = os.getenv(
    "APIGATEWAY_API_NAME",
)

APIGATEWAY_PROTOCOL_TYPE = os.getenv(
    "APIGATEWAY_PROTOCOL_TYPE",
    "HTTP",
)

APIGATEWAY_DESCRIPTION = os.getenv(
    "APIGATEWAY_DESCRIPTION",
)


# ============================================================
# Expected Integration Configuration
# ============================================================

APIGATEWAY_INTEGRATION_TYPE = os.getenv(
    "APIGATEWAY_INTEGRATION_TYPE",
    "AWS_PROXY",
)

APIGATEWAY_INTEGRATION_URI = os.getenv(
    "APIGATEWAY_INTEGRATION_URI",
)

APIGATEWAY_INTEGRATION_METHOD = os.getenv(
    "APIGATEWAY_INTEGRATION_METHOD",
    "POST",
)

APIGATEWAY_PAYLOAD_FORMAT_VERSION = os.getenv(
    "APIGATEWAY_PAYLOAD_FORMAT_VERSION",
    "2.0",
)

APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS = int(
    os.getenv(
        "APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS",
        "30000",
    )
)


# ============================================================
# Expected Route Configuration
# ============================================================

APIGATEWAY_ROUTE_KEY = os.getenv(
    "APIGATEWAY_ROUTE_KEY",
    "POST /",
)

APIGATEWAY_ROUTE_AUTHORIZATION_TYPE = os.getenv(
    "APIGATEWAY_ROUTE_AUTHORIZATION_TYPE",
    "NONE",
)

APIGATEWAY_AUTHORIZER_ID = os.getenv(
    "APIGATEWAY_AUTHORIZER_ID",
)


# ============================================================
# Expected Stage Configuration
# ============================================================

APIGATEWAY_STAGE_NAME = os.getenv(
    "APIGATEWAY_STAGE_NAME",
    "$default",
)

APIGATEWAY_AUTO_DEPLOY = (
    os.getenv(
        "APIGATEWAY_AUTO_DEPLOY",
        "true",
    ).lower()
    == "true"
)

APIGATEWAY_THROTTLING_BURST_LIMIT = int(
    os.getenv(
        "APIGATEWAY_THROTTLING_BURST_LIMIT",
        "100",
    )
)

APIGATEWAY_THROTTLING_RATE_LIMIT = float(
    os.getenv(
        "APIGATEWAY_THROTTLING_RATE_LIMIT",
        "50",
    )
)


# ============================================================
# Expected CORS Configuration
# ============================================================

APIGATEWAY_CORS_ENABLED = (
    os.getenv(
        "APIGATEWAY_CORS_ENABLED",
        "false",
    ).lower()
    == "true"
)

APIGATEWAY_CORS_ALLOW_ORIGINS_JSON = os.getenv(
    "APIGATEWAY_CORS_ALLOW_ORIGINS_JSON",
    '["*"]',
)

APIGATEWAY_CORS_ALLOW_METHODS_JSON = os.getenv(
    "APIGATEWAY_CORS_ALLOW_METHODS_JSON",
    '["GET","POST","OPTIONS"]',
)

APIGATEWAY_CORS_ALLOW_HEADERS_JSON = os.getenv(
    "APIGATEWAY_CORS_ALLOW_HEADERS_JSON",
    '["content-type","authorization"]',
)

APIGATEWAY_CORS_EXPOSE_HEADERS_JSON = os.getenv(
    "APIGATEWAY_CORS_EXPOSE_HEADERS_JSON",
    "[]",
)

APIGATEWAY_CORS_ALLOW_CREDENTIALS = (
    os.getenv(
        "APIGATEWAY_CORS_ALLOW_CREDENTIALS",
        "false",
    ).lower()
    == "true"
)

APIGATEWAY_CORS_MAX_AGE = int(
    os.getenv(
        "APIGATEWAY_CORS_MAX_AGE",
        "0",
    )
)


# ============================================================
# Runtime HTTP Test
# ============================================================

APIGATEWAY_TEST_PATH = os.getenv(
    "APIGATEWAY_TEST_PATH",
    "/",
)

APIGATEWAY_TEST_METHOD = os.getenv(
    "APIGATEWAY_TEST_METHOD",
    "POST",
).upper()

APIGATEWAY_TEST_PAYLOAD_JSON = os.getenv(
    "APIGATEWAY_TEST_PAYLOAD_JSON",
    '{"order_id":"pytest-api-order-001","source":"apigateway"}',
)

APIGATEWAY_EXPECTED_STATUS_CODE = int(
    os.getenv(
        "APIGATEWAY_EXPECTED_STATUS_CODE",
        "200",
    )
)

APIGATEWAY_EXPECTED_RESPONSE_JSON = os.getenv(
    "APIGATEWAY_EXPECTED_RESPONSE_JSON",
)


# ============================================================
# Expected Identity
# ============================================================

EXPECTED_API_NAME = (
    APIGATEWAY_API_NAME
    if APIGATEWAY_API_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-api"
)


# ============================================================
# Session Guard
# ============================================================

@pytest.fixture(
    scope="session",
    autouse=True,
)
def apigateway_enabled_guard():
    if not APIGATEWAY_ENABLED:
        pytest.skip(
            "API Gateway is disabled "
            "for this environment."
        )


# ============================================================
# Helpers
# ============================================================

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

    assert isinstance(
        value,
        list,
    ), (
        f"{variable_name} must contain "
        "a JSON array."
    )

    return value


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

    assert isinstance(
        value,
        dict,
    ), (
        f"{variable_name} must contain "
        "a JSON object."
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

        except json.JSONDecodeError:
            return value

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
def apigateway_client():
    return boto3.client(
        "apigatewayv2",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# API Discovery
# ============================================================

def get_apis(
    client,
):
    items = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_apis(
            **kwargs
        )

        items.extend(
            response.get(
                "Items",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return items


@pytest.fixture(
    scope="session"
)
def api(
    apigateway_client,
):
    try:
        for item in get_apis(
            apigateway_client
        ):
            if (
                item.get("Name")
                == EXPECTED_API_NAME
            ):
                return item

    except (
        ClientError,
        BotoCoreError,
    ) as error:
        pytest.fail(
            "Unable to query API Gateway APIs: "
            f"{error}"
        )

    pytest.fail(
        "API Gateway HTTP API not found: "
        f"{EXPECTED_API_NAME}"
    )


@pytest.fixture(
    scope="session"
)
def api_id(
    api,
):
    value = api.get(
        "ApiId"
    )

    assert value, (
        "API Gateway ApiId is missing."
    )

    return value


# ============================================================
# Related Resources
# ============================================================

@pytest.fixture(
    scope="session"
)
def integrations(
    apigateway_client,
    api_id,
):
    items = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = apigateway_client.get_integrations(
            **kwargs
        )

        items.extend(
            response.get(
                "Items",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return items


@pytest.fixture(
    scope="session"
)
def routes(
    apigateway_client,
    api_id,
):
    items = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = apigateway_client.get_routes(
            **kwargs
        )

        items.extend(
            response.get(
                "Items",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return items


@pytest.fixture(
    scope="session"
)
def stages(
    apigateway_client,
    api_id,
):
    items = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = apigateway_client.get_stages(
            **kwargs
        )

        items.extend(
            response.get(
                "Items",
                [],
            )
        )

        next_token = response.get(
            "NextToken"
        )

        if not next_token:
            break

    return items


@pytest.fixture(
    scope="session"
)
def expected_stage(
    stages,
):
    stage = next(
        (
            item
            for item in stages
            if (
                item.get("StageName")
                == APIGATEWAY_STAGE_NAME
            )
        ),
        None,
    )

    assert stage, (
        "Expected API Gateway stage "
        f"not found: {APIGATEWAY_STAGE_NAME}"
    )

    return stage


@pytest.fixture(
    scope="session"
)
def expected_route(
    routes,
):
    route = next(
        (
            item
            for item in routes
            if (
                item.get("RouteKey")
                == APIGATEWAY_ROUTE_KEY
            )
        ),
        None,
    )

    assert route, (
        "Expected API Gateway route "
        f"not found: {APIGATEWAY_ROUTE_KEY}"
    )

    return route


@pytest.fixture(
    scope="session"
)
def expected_integration(
    integrations,
    expected_route,
):
    target = expected_route.get(
        "Target",
        "",
    )

    assert target.startswith(
        "integrations/"
    ), (
        "Route target does not reference "
        f"an integration: {target}"
    )

    integration_id = target.split(
        "/",
        1,
    )[1]

    integration = next(
        (
            item
            for item in integrations
            if (
                item.get("IntegrationId")
                == integration_id
            )
        ),
        None,
    )

    assert integration, (
        "Integration referenced by route "
        f"was not found: {integration_id}"
    )

    return integration


# ============================================================
# API Tests
# ============================================================

def test_api_gateway_api_available(
    apigateway_client,
):
    response = apigateway_client.get_apis(
        MaxResults="1",
    )

    status_code = response.get(
        "ResponseMetadata",
        {},
    ).get(
        "HTTPStatusCode"
    )

    assert status_code == 200


def test_api_name(
    api,
):
    assert (
        api.get("Name")
        == EXPECTED_API_NAME
    )


def test_api_protocol(
    api,
):
    assert (
        api.get("ProtocolType")
        == APIGATEWAY_PROTOCOL_TYPE
    )


def test_api_endpoint_exists(
    api,
):
    endpoint = api.get(
        "ApiEndpoint"
    )

    assert endpoint
    assert endpoint.startswith(
        (
            "http://",
            "https://",
        )
    )


def test_api_description(
    api,
):
    if APIGATEWAY_DESCRIPTION is None:
        pytest.skip(
            "APIGATEWAY_DESCRIPTION "
            "is not configured."
        )

    assert (
        api.get(
            "Description",
            "",
        )
        == APIGATEWAY_DESCRIPTION
    )


# ============================================================
# CORS Tests
# ============================================================

def test_cors_configuration(
    api,
):
    actual = api.get(
        "CorsConfiguration"
    )

    if not APIGATEWAY_CORS_ENABLED:
        assert not actual
        return

    assert actual

    expected_origins = set(
        parse_json_list(
            APIGATEWAY_CORS_ALLOW_ORIGINS_JSON,
            "APIGATEWAY_CORS_ALLOW_ORIGINS_JSON",
        )
    )

    expected_methods = set(
        parse_json_list(
            APIGATEWAY_CORS_ALLOW_METHODS_JSON,
            "APIGATEWAY_CORS_ALLOW_METHODS_JSON",
        )
    )

    expected_headers = set(
        parse_json_list(
            APIGATEWAY_CORS_ALLOW_HEADERS_JSON,
            "APIGATEWAY_CORS_ALLOW_HEADERS_JSON",
        )
    )

    expected_expose_headers = set(
        parse_json_list(
            APIGATEWAY_CORS_EXPOSE_HEADERS_JSON,
            "APIGATEWAY_CORS_EXPOSE_HEADERS_JSON",
        )
    )

    assert (
        set(
            actual.get(
                "AllowOrigins",
                [],
            )
        )
        == expected_origins
    )

    assert (
        set(
            actual.get(
                "AllowMethods",
                [],
            )
        )
        == expected_methods
    )

    assert (
        set(
            actual.get(
                "AllowHeaders",
                [],
            )
        )
        == expected_headers
    )

    assert (
        set(
            actual.get(
                "ExposeHeaders",
                [],
            )
        )
        == expected_expose_headers
    )

    assert (
        actual.get(
            "AllowCredentials",
            False,
        )
        == APIGATEWAY_CORS_ALLOW_CREDENTIALS
    )

    assert (
        actual.get(
            "MaxAge",
            0,
        )
        == APIGATEWAY_CORS_MAX_AGE
    )


# ============================================================
# Integration Tests
# ============================================================

def test_integration_exists(
    expected_integration,
):
    assert expected_integration.get(
        "IntegrationId"
    )


def test_integration_type(
    expected_integration,
):
    assert (
        expected_integration.get(
            "IntegrationType"
        )
        == APIGATEWAY_INTEGRATION_TYPE
    )


def test_integration_method(
    expected_integration,
):
    assert (
        expected_integration.get(
            "IntegrationMethod"
        )
        == APIGATEWAY_INTEGRATION_METHOD
    )


def test_payload_format_version(
    expected_integration,
):
    assert (
        expected_integration.get(
            "PayloadFormatVersion"
        )
        == APIGATEWAY_PAYLOAD_FORMAT_VERSION
    )


def test_integration_timeout(
    expected_integration,
):
    assert (
        expected_integration.get(
            "TimeoutInMillis"
        )
        == APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS
    )


def test_integration_uri(
    expected_integration,
):
    actual = expected_integration.get(
        "IntegrationUri"
    )

    assert actual

    if APIGATEWAY_INTEGRATION_URI:
        assert (
            actual
            == APIGATEWAY_INTEGRATION_URI
        )


# ============================================================
# Route Tests
# ============================================================

def test_route_key(
    expected_route,
):
    assert (
        expected_route.get(
            "RouteKey"
        )
        == APIGATEWAY_ROUTE_KEY
    )


def test_route_authorization_type(
    expected_route,
):
    assert (
        expected_route.get(
            "AuthorizationType"
        )
        == APIGATEWAY_ROUTE_AUTHORIZATION_TYPE
    )


def test_route_authorizer(
    expected_route,
):
    actual = expected_route.get(
        "AuthorizerId"
    )

    if APIGATEWAY_AUTHORIZER_ID:
        assert (
            actual
            == APIGATEWAY_AUTHORIZER_ID
        )

    elif (
        APIGATEWAY_ROUTE_AUTHORIZATION_TYPE
        == "NONE"
    ):
        assert not actual


def test_route_target(
    expected_route,
):
    target = expected_route.get(
        "Target"
    )

    assert isinstance(
        target,
        str,
    )

    assert target.startswith(
        "integrations/"
    )


# ============================================================
# Stage Tests
# ============================================================

def test_stage_name(
    expected_stage,
):
    assert (
        expected_stage.get(
            "StageName"
        )
        == APIGATEWAY_STAGE_NAME
    )


def test_stage_auto_deploy(
    expected_stage,
):
    assert (
        expected_stage.get(
            "AutoDeploy",
            False,
        )
        == APIGATEWAY_AUTO_DEPLOY
    )


def test_stage_throttling_burst_limit(
    expected_stage,
):
    settings = expected_stage.get(
        "DefaultRouteSettings",
        {},
    )

    assert (
        settings.get(
            "ThrottlingBurstLimit"
        )
        == APIGATEWAY_THROTTLING_BURST_LIMIT
    )


def test_stage_throttling_rate_limit(
    expected_stage,
):
    settings = expected_stage.get(
        "DefaultRouteSettings",
        {},
    )

    assert (
        settings.get(
            "ThrottlingRateLimit"
        )
        == APIGATEWAY_THROTTLING_RATE_LIMIT
    )


# ============================================================
# Runtime URL
# ============================================================

@pytest.fixture(
    scope="session"
)
def invoke_url(
    api,
):
    endpoint = api.get(
        "ApiEndpoint"
    )

    assert endpoint

    endpoint = endpoint.rstrip(
        "/"
    )

    path = APIGATEWAY_TEST_PATH

    if not path.startswith(
        "/"
    ):
        path = f"/{path}"

    if APIGATEWAY_STAGE_NAME == "$default":
        return (
            f"{endpoint}{path}"
        )

    return (
        f"{endpoint}/"
        f"{APIGATEWAY_STAGE_NAME}"
        f"{path}"
    )


# ============================================================
# Runtime HTTP Invocation
# ============================================================

@pytest.fixture(
    scope="session"
)
def http_result(
    invoke_url,
):
    payload = parse_json_object(
        APIGATEWAY_TEST_PAYLOAD_JSON,
        "APIGATEWAY_TEST_PAYLOAD_JSON",
    )

    body = json.dumps(
        payload
    ).encode(
        "utf-8"
    )

    request = urllib.request.Request(
        invoke_url,
        data=body,
        method=APIGATEWAY_TEST_METHOD,
        headers={
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(
            request,
            timeout=30,
        ) as response:
            raw_body = response.read()

            if isinstance(
                raw_body,
                bytes,
            ):
                raw_body = raw_body.decode(
                    "utf-8"
                )

            return {
                "status_code": response.status,
                "headers": dict(
                    response.headers.items()
                ),
                "body": raw_body,
                "url": invoke_url,
                "input": payload,
            }

    except urllib.error.HTTPError as error:
        raw_body = error.read()

        if isinstance(
            raw_body,
            bytes,
        ):
            raw_body = raw_body.decode(
                "utf-8"
            )

        return {
            "status_code": error.code,
            "headers": dict(
                error.headers.items()
            ),
            "body": raw_body,
            "url": invoke_url,
            "input": payload,
        }

    except urllib.error.URLError as error:
        pytest.fail(
            "API Gateway HTTP request failed: "
            f"{error}. URL={invoke_url}"
        )


# ============================================================
# Runtime Tests
# ============================================================

def test_http_status_code(
    http_result,
):
    assert (
        http_result[
            "status_code"
        ]
        == APIGATEWAY_EXPECTED_STATUS_CODE
    ), (
        "Unexpected API Gateway HTTP status. "
        f"URL={http_result['url']} "
        f"Body={http_result['body']}"
    )


def test_http_response_body_not_empty(
    http_result,
):
    assert (
        http_result[
            "body"
        ]
        is not None
    )

    assert (
        http_result[
            "body"
        ].strip()
    )


def test_http_response_is_valid_json(
    http_result,
):
    try:
        parsed = json.loads(
            http_result[
                "body"
            ]
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "API Gateway response body "
            f"is not valid JSON: {error}. "
            f"Body={http_result['body']!r}"
        )

    assert parsed is not None


def test_http_response_matches_expected(
    http_result,
):
    if not APIGATEWAY_EXPECTED_RESPONSE_JSON:
        pytest.skip(
            "APIGATEWAY_EXPECTED_RESPONSE_JSON "
            "is not configured."
        )

    try:
        expected = json.loads(
            APIGATEWAY_EXPECTED_RESPONSE_JSON
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "APIGATEWAY_EXPECTED_RESPONSE_JSON "
            f"is invalid: {error}"
        )

    try:
        actual = json.loads(
            http_result[
                "body"
            ]
        )

    except json.JSONDecodeError as error:
        pytest.fail(
            "API Gateway response body "
            f"is invalid JSON: {error}"
        )

    assert (
        normalize_json(
            actual
        )
        == normalize_json(
            expected
        )
    )