import json
import os
import re
import sys

import boto3
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

APIGATEWAY_ENABLED = os.getenv(
    "APIGATEWAY_ENABLED",
    "true",
).lower() == "true"


# ============================================================
# Expected Configuration
# ============================================================

APIGATEWAY_API_NAME = os.getenv(
    "APIGATEWAY_API_NAME",
)

APIGATEWAY_DESCRIPTION = os.getenv(
    "APIGATEWAY_DESCRIPTION",
)

APIGATEWAY_PROTOCOL_TYPE = os.getenv(
    "APIGATEWAY_PROTOCOL_TYPE",
    "HTTP",
)

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

APIGATEWAY_STAGE_NAME = os.getenv(
    "APIGATEWAY_STAGE_NAME",
    "$default",
)

APIGATEWAY_AUTO_DEPLOY = os.getenv(
    "APIGATEWAY_AUTO_DEPLOY",
    "true",
).lower() == "true"

APIGATEWAY_CORS_ENABLED = os.getenv(
    "APIGATEWAY_CORS_ENABLED",
    "false",
).lower() == "true"

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

APIGATEWAY_CORS_ALLOW_CREDENTIALS = os.getenv(
    "APIGATEWAY_CORS_ALLOW_CREDENTIALS",
    "false",
).lower() == "true"

APIGATEWAY_CORS_MAX_AGE = int(
    os.getenv(
        "APIGATEWAY_CORS_MAX_AGE",
        "0",
    )
)

APIGATEWAY_ACCESS_LOGGING_ENABLED = os.getenv(
    "APIGATEWAY_ACCESS_LOGGING_ENABLED",
    "false",
).lower() == "true"

APIGATEWAY_ACCESS_LOG_DESTINATION_ARN = os.getenv(
    "APIGATEWAY_ACCESS_LOG_DESTINATION_ARN",
)

APIGATEWAY_ACCESS_LOG_FORMAT = os.getenv(
    "APIGATEWAY_ACCESS_LOG_FORMAT",
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
# Expected Identity
# ============================================================

EXPECTED_API_NAME = (
    APIGATEWAY_API_NAME
    if APIGATEWAY_API_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-api"
)

EXPECTED_TAGS = {
    "Project": PROJECT_NAME,
    "Environment": ENVIRONMENT,
    "Name": EXPECTED_API_NAME,
    "Component": "api",
    "Service": "apigateway",
}


# ============================================================
# Counters
# ============================================================

PASS_COUNT = 0
WARN_COUNT = 0
FAIL_COUNT = 0


def pass_check(
    message,
):
    global PASS_COUNT

    PASS_COUNT += 1

    print(
        f"[PASS] {message}"
    )


def warn_check(
    message,
):
    global WARN_COUNT

    WARN_COUNT += 1

    print(
        f"[WARN] {message}"
    )


def fail_check(
    message,
):
    global FAIL_COUNT

    FAIL_COUNT += 1

    print(
        f"[FAIL] {message}"
    )


# ============================================================
# Client
# ============================================================

def create_apigateway_client():
    return boto3.client(
        "apigatewayv2",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )


# ============================================================
# JSON Helpers
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
# API Discovery
# ============================================================

def get_apis(
    client,
):
    apis = []
    next_token = None

    while True:
        kwargs = {}

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_apis(
            **kwargs
        )

        apis.extend(
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

    return apis


def get_expected_api(
    client,
):
    for api in get_apis(
        client
    ):
        if (
            api.get("Name")
            == EXPECTED_API_NAME
        ):
            return api

    return None


# ============================================================
# Related Resources
# ============================================================

def get_integrations(
    client,
    api_id,
):
    response = client.get_integrations(
        ApiId=api_id,
    )

    return response.get(
        "Items",
        [],
    )


def get_routes(
    client,
    api_id,
):
    response = client.get_routes(
        ApiId=api_id,
    )

    return response.get(
        "Items",
        [],
    )


def get_stages(
    client,
    api_id,
):
    response = client.get_stages(
        ApiId=api_id,
    )

    return response.get(
        "Items",
        [],
    )


def get_tags(
    client,
    api_arn,
):
    try:
        response = client.get_tags(
            ResourceArn=api_arn,
        )

        return response.get(
            "Tags",
            {},
        )

    except ClientError as error:
        warn_check(
            "Unable to read API Gateway tags: "
            f"{error}"
        )

        return {}


# ============================================================
# Exists
# ============================================================

def validate_api_exists(
    api,
):
    if api is None:
        fail_check(
            "API Gateway HTTP API not found: "
            f"{EXPECTED_API_NAME}"
        )

        return False

    pass_check(
        "API Gateway HTTP API exists: "
        f"{EXPECTED_API_NAME}"
    )

    return True


# ============================================================
# Identity
# ============================================================

def validate_identity(
    api,
):
    api_name = api.get(
        "Name"
    )

    if api_name == EXPECTED_API_NAME:
        pass_check(
            "API Gateway name matches expected value."
        )
    else:
        fail_check(
            "API Gateway name expected "
            f"{EXPECTED_API_NAME}, got {api_name}"
        )

    api_id = api.get(
        "ApiId"
    )

    if api_id:
        pass_check(
            "API Gateway ApiId exists."
        )
    else:
        fail_check(
            "API Gateway ApiId is missing."
        )

    endpoint = api.get(
        "ApiEndpoint"
    )

    if endpoint:
        pass_check(
            "API Gateway endpoint exists."
        )
    else:
        fail_check(
            "API Gateway endpoint is missing."
        )


# ============================================================
# Protocol
# ============================================================

def validate_protocol(
    api,
):
    actual = api.get(
        "ProtocolType"
    )

    if actual == APIGATEWAY_PROTOCOL_TYPE:
        pass_check(
            "API Gateway protocol type matches "
            f"expected value: {actual}"
        )
    else:
        fail_check(
            "API Gateway protocol type expected "
            f"{APIGATEWAY_PROTOCOL_TYPE}, "
            f"got {actual}"
        )


# ============================================================
# Description
# ============================================================

def validate_description(
    api,
):
    if APIGATEWAY_DESCRIPTION is None:
        return

    actual = api.get(
        "Description",
        "",
    )

    if actual == APIGATEWAY_DESCRIPTION:
        pass_check(
            "API Gateway description matches expected value."
        )
    else:
        fail_check(
            "API Gateway description expected "
            f"{APIGATEWAY_DESCRIPTION!r}, "
            f"got {actual!r}"
        )


# ============================================================
# CORS
# ============================================================

def validate_cors(
    api,
):
    actual = api.get(
        "CorsConfiguration"
    )

    if not APIGATEWAY_CORS_ENABLED:
        if not actual:
            pass_check(
                "API Gateway CORS is disabled."
            )
        else:
            fail_check(
                "API Gateway CORS is configured "
                "although it is expected to be disabled."
            )

        return

    if not actual:
        fail_check(
            "API Gateway CORS configuration is missing."
        )
        return

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

    expected_expose = set(
        parse_json_list(
            APIGATEWAY_CORS_EXPOSE_HEADERS_JSON,
            "APIGATEWAY_CORS_EXPOSE_HEADERS_JSON",
        )
    )

    checks = [
        (
            "CORS allow origins",
            set(actual.get("AllowOrigins", [])),
            expected_origins,
        ),
        (
            "CORS allow methods",
            set(actual.get("AllowMethods", [])),
            expected_methods,
        ),
        (
            "CORS allow headers",
            set(actual.get("AllowHeaders", [])),
            expected_headers,
        ),
        (
            "CORS expose headers",
            set(actual.get("ExposeHeaders", [])),
            expected_expose,
        ),
    ]

    for (
        label,
        actual_value,
        expected_value,
    ) in checks:
        if actual_value == expected_value:
            pass_check(
                f"{label} match expected configuration."
            )
        else:
            fail_check(
                f"{label} expected "
                f"{sorted(expected_value)}, "
                f"got {sorted(actual_value)}"
            )

    actual_credentials = actual.get(
        "AllowCredentials",
        False,
    )

    if (
        actual_credentials
        == APIGATEWAY_CORS_ALLOW_CREDENTIALS
    ):
        pass_check(
            "CORS allow credentials matches expected value."
        )
    else:
        fail_check(
            "CORS allow credentials expected "
            f"{APIGATEWAY_CORS_ALLOW_CREDENTIALS}, "
            f"got {actual_credentials}"
        )

    actual_max_age = actual.get(
        "MaxAge",
        0,
    )

    if actual_max_age == APIGATEWAY_CORS_MAX_AGE:
        pass_check(
            "CORS max age matches expected value."
        )
    else:
        fail_check(
            "CORS max age expected "
            f"{APIGATEWAY_CORS_MAX_AGE}, "
            f"got {actual_max_age}"
        )


# ============================================================
# Integration
# ============================================================

def validate_integrations(
    integrations,
):
    if not integrations:
        fail_check(
            "No API Gateway integrations are configured."
        )
        return

    pass_check(
        f"API Gateway has {len(integrations)} integration(s)."
    )

    integration = integrations[0]

    checks = [
        (
            "Integration type",
            integration.get("IntegrationType"),
            APIGATEWAY_INTEGRATION_TYPE,
        ),
        (
            "Integration method",
            integration.get("IntegrationMethod"),
            APIGATEWAY_INTEGRATION_METHOD,
        ),
        (
            "Payload format version",
            integration.get("PayloadFormatVersion"),
            APIGATEWAY_PAYLOAD_FORMAT_VERSION,
        ),
        (
            "Integration timeout",
            integration.get("TimeoutInMillis"),
            APIGATEWAY_INTEGRATION_TIMEOUT_MILLISECONDS,
        ),
    ]

    for (
        label,
        actual,
        expected,
    ) in checks:
        if actual == expected:
            pass_check(
                f"{label} matches expected value."
            )
        else:
            fail_check(
                f"{label} expected "
                f"{expected}, got {actual}"
            )

    actual_uri = integration.get(
        "IntegrationUri"
    )

    if APIGATEWAY_INTEGRATION_URI:
        if actual_uri == APIGATEWAY_INTEGRATION_URI:
            pass_check(
                "Integration URI matches expected value."
            )
        else:
            fail_check(
                "Integration URI expected "
                f"{APIGATEWAY_INTEGRATION_URI}, "
                f"got {actual_uri}"
            )
    elif actual_uri:
        pass_check(
            "Integration URI exists."
        )
    else:
        fail_check(
            "Integration URI is missing."
        )


# ============================================================
# Route
# ============================================================

def validate_routes(
    routes,
):
    if not routes:
        fail_check(
            "No API Gateway routes are configured."
        )
        return

    expected_route = next(
        (
            route
            for route in routes
            if route.get("RouteKey")
            == APIGATEWAY_ROUTE_KEY
        ),
        None,
    )

    if not expected_route:
        fail_check(
            "Expected API Gateway route not found: "
            f"{APIGATEWAY_ROUTE_KEY}"
        )
        return

    pass_check(
        "Expected API Gateway route exists: "
        f"{APIGATEWAY_ROUTE_KEY}"
    )

    actual_auth = expected_route.get(
        "AuthorizationType"
    )

    if (
        actual_auth
        == APIGATEWAY_ROUTE_AUTHORIZATION_TYPE
    ):
        pass_check(
            "Route authorization type matches expected value."
        )
    else:
        fail_check(
            "Route authorization type expected "
            f"{APIGATEWAY_ROUTE_AUTHORIZATION_TYPE}, "
            f"got {actual_auth}"
        )

    actual_authorizer = expected_route.get(
        "AuthorizerId"
    )

    if APIGATEWAY_AUTHORIZER_ID:
        if actual_authorizer == APIGATEWAY_AUTHORIZER_ID:
            pass_check(
                "Route authorizer ID matches expected value."
            )
        else:
            fail_check(
                "Route authorizer ID expected "
                f"{APIGATEWAY_AUTHORIZER_ID}, "
                f"got {actual_authorizer}"
            )

    target = expected_route.get(
        "Target"
    )

    if (
        isinstance(target, str)
        and target.startswith("integrations/")
    ):
        pass_check(
            "Route target references an integration."
        )
    else:
        fail_check(
            "Route target is invalid: "
            f"{target}"
        )


# ============================================================
# Stage
# ============================================================

def validate_stages(
    stages,
):
    expected_stage = next(
        (
            stage
            for stage in stages
            if stage.get("StageName")
            == APIGATEWAY_STAGE_NAME
        ),
        None,
    )

    if not expected_stage:
        fail_check(
            "Expected API Gateway stage not found: "
            f"{APIGATEWAY_STAGE_NAME}"
        )
        return

    pass_check(
        "Expected API Gateway stage exists: "
        f"{APIGATEWAY_STAGE_NAME}"
    )

    actual_auto_deploy = expected_stage.get(
        "AutoDeploy",
        False,
    )

    if actual_auto_deploy == APIGATEWAY_AUTO_DEPLOY:
        pass_check(
            "Stage auto deploy matches expected value."
        )
    else:
        fail_check(
            "Stage auto deploy expected "
            f"{APIGATEWAY_AUTO_DEPLOY}, "
            f"got {actual_auto_deploy}"
        )

    route_settings = expected_stage.get(
        "DefaultRouteSettings",
        {},
    )

    actual_burst = route_settings.get(
        "ThrottlingBurstLimit"
    )

    actual_rate = route_settings.get(
        "ThrottlingRateLimit"
    )

    if actual_burst == APIGATEWAY_THROTTLING_BURST_LIMIT:
        pass_check(
            "Stage throttling burst limit matches expected value."
        )
    else:
        fail_check(
            "Stage throttling burst limit expected "
            f"{APIGATEWAY_THROTTLING_BURST_LIMIT}, "
            f"got {actual_burst}"
        )

    if actual_rate == APIGATEWAY_THROTTLING_RATE_LIMIT:
        pass_check(
            "Stage throttling rate limit matches expected value."
        )
    else:
        fail_check(
            "Stage throttling rate limit expected "
            f"{APIGATEWAY_THROTTLING_RATE_LIMIT}, "
            f"got {actual_rate}"
        )


# ============================================================
# Access Logging
# ============================================================

def validate_access_logging(
    stages,
):
    expected_stage = next(
        (
            stage
            for stage in stages
            if stage.get("StageName")
            == APIGATEWAY_STAGE_NAME
        ),
        None,
    )

    if not expected_stage:
        return

    actual = expected_stage.get(
        "AccessLogSettings"
    )

    if not APIGATEWAY_ACCESS_LOGGING_ENABLED:
        if not actual:
            pass_check(
                "API Gateway access logging is disabled."
            )
        else:
            fail_check(
                "Access logging is configured although "
                "it is expected to be disabled."
            )

        return

    if not actual:
        fail_check(
            "API Gateway access logging configuration is missing."
        )
        return

    actual_destination = actual.get(
        "DestinationArn"
    )

    if (
        actual_destination
        == APIGATEWAY_ACCESS_LOG_DESTINATION_ARN
    ):
        pass_check(
            "Access log destination matches expected ARN."
        )
    else:
        fail_check(
            "Access log destination expected "
            f"{APIGATEWAY_ACCESS_LOG_DESTINATION_ARN}, "
            f"got {actual_destination}"
        )

    if APIGATEWAY_ACCESS_LOG_FORMAT:
        actual_format = actual.get(
            "Format"
        )

        if actual_format == APIGATEWAY_ACCESS_LOG_FORMAT:
            pass_check(
                "Access log format matches expected value."
            )
        else:
            fail_check(
                "Access log format does not match expected value."
            )


# ============================================================
# Tags
# ============================================================

def validate_tags(
    tags,
):
    if not tags:
        warn_check(
            "API Gateway tags were not returned."
        )
        return

    for (
        key,
        expected_value,
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
                f"Required API Gateway tag missing: {key}"
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
        "API GATEWAY VALIDATION SUMMARY"
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
    if not APIGATEWAY_ENABLED:
        pass_check(
            "API Gateway is disabled for this environment."
        )
        return

    client = create_apigateway_client()

    api = get_expected_api(
        client
    )

    if not validate_api_exists(
        api
    ):
        return

    api_id = api.get(
        "ApiId"
    )

    integrations = get_integrations(
        client,
        api_id,
    )

    routes = get_routes(
        client,
        api_id,
    )

    stages = get_stages(
        client,
        api_id,
    )

    api_arn = (
        f"arn:aws:apigateway:"
        f"{AWS_REGION}::/apis/{api_id}"
    )

    tags = get_tags(
        client,
        api_arn,
    )

    validate_identity(
        api
    )

    validate_protocol(
        api
    )

    validate_description(
        api
    )

    validate_cors(
        api
    )

    validate_integrations(
        integrations
    )

    validate_routes(
        routes
    )

    validate_stages(
        stages
    )

    validate_access_logging(
        stages
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