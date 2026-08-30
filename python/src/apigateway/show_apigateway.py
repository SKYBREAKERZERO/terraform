import os
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

APIGATEWAY_API_NAME = os.getenv(
    "APIGATEWAY_API_NAME",
)

EXPECTED_API_NAME = (
    APIGATEWAY_API_NAME
    if APIGATEWAY_API_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-api"
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


def get_api(
    client,
):
    apis = get_apis(
        client
    )

    for api in apis:
        if (
            api.get("Name")
            == EXPECTED_API_NAME
        ):
            return api

    raise RuntimeError(
        "API Gateway HTTP API not found: "
        f"{EXPECTED_API_NAME}"
    )


# ============================================================
# Integrations
# ============================================================

def get_integrations(
    client,
    api_id,
):
    integrations = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_integrations(
            **kwargs
        )

        integrations.extend(
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

    return integrations


# ============================================================
# Routes
# ============================================================

def get_routes(
    client,
    api_id,
):
    routes = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_routes(
            **kwargs
        )

        routes.extend(
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

    return routes


# ============================================================
# Stages
# ============================================================

def get_stages(
    client,
    api_id,
):
    stages = []
    next_token = None

    while True:
        kwargs = {
            "ApiId": api_id,
        }

        if next_token:
            kwargs["NextToken"] = next_token

        response = client.get_stages(
            **kwargs
        )

        stages.extend(
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

    return stages


# ============================================================
# Tags
# ============================================================

def get_tags(
    client,
    resource_arn,
):
    if not resource_arn:
        return {}

    response = client.get_tags(
        ResourceArn=resource_arn,
    )

    return response.get(
        "Tags",
        {},
    )


# ============================================================
# Output Helpers
# ============================================================

def print_separator(
    character="=",
):
    print(
        character * 70
    )


def print_api(
    api,
):
    print_separator()
    print("API GATEWAY HTTP API")
    print_separator()

    print(
        f"Name:                 "
        f"{api.get('Name', '')}"
    )

    print(
        f"API ID:               "
        f"{api.get('ApiId', '')}"
    )

    print(
        f"Protocol Type:        "
        f"{api.get('ProtocolType', '')}"
    )

    print(
        f"Description:          "
        f"{api.get('Description') or ''}"
    )

    print(
        f"API Endpoint:         "
        f"{api.get('ApiEndpoint', '')}"
    )

    print(
        f"Disable Execute API:  "
        f"{api.get('DisableExecuteApiEndpoint', False)}"
    )


def print_cors(
    api,
):
    print()
    print_separator()
    print("CORS")
    print_separator()

    cors = api.get(
        "CorsConfiguration"
    )

    if not cors:
        print("Enabled:              false")
        return

    print("Enabled:              true")

    print(
        f"Allow Origins:        "
        f"{', '.join(cors.get('AllowOrigins', [])) or 'none'}"
    )

    print(
        f"Allow Methods:        "
        f"{', '.join(cors.get('AllowMethods', [])) or 'none'}"
    )

    print(
        f"Allow Headers:        "
        f"{', '.join(cors.get('AllowHeaders', [])) or 'none'}"
    )

    print(
        f"Expose Headers:       "
        f"{', '.join(cors.get('ExposeHeaders', [])) or 'none'}"
    )

    print(
        f"Allow Credentials:    "
        f"{cors.get('AllowCredentials', False)}"
    )

    print(
        f"Max Age:              "
        f"{cors.get('MaxAge', 0)}"
    )


def print_integrations(
    integrations,
):
    print()
    print_separator()
    print("INTEGRATIONS")
    print_separator()

    if not integrations:
        print("No integrations configured.")
        return

    for index, integration in enumerate(
        integrations,
        start=1,
    ):
        print(
            f"[{index}]"
        )

        print(
            f"Integration ID:       "
            f"{integration.get('IntegrationId', '')}"
        )

        print(
            f"Integration Type:     "
            f"{integration.get('IntegrationType', '')}"
        )

        print(
            f"Integration URI:      "
            f"{integration.get('IntegrationUri', '')}"
        )

        print(
            f"Integration Method:   "
            f"{integration.get('IntegrationMethod', '')}"
        )

        print(
            f"Payload Version:      "
            f"{integration.get('PayloadFormatVersion', '')}"
        )

        print(
            f"Timeout:              "
            f"{integration.get('TimeoutInMillis', '')} ms"
        )

        if index < len(integrations):
            print()


def print_routes(
    routes,
):
    print()
    print_separator()
    print("ROUTES")
    print_separator()

    if not routes:
        print("No routes configured.")
        return

    for index, route in enumerate(
        routes,
        start=1,
    ):
        print(
            f"[{index}]"
        )

        print(
            f"Route ID:             "
            f"{route.get('RouteId', '')}"
        )

        print(
            f"Route Key:            "
            f"{route.get('RouteKey', '')}"
        )

        print(
            f"Target:               "
            f"{route.get('Target', '')}"
        )

        print(
            f"Authorization Type:   "
            f"{route.get('AuthorizationType', '')}"
        )

        print(
            f"Authorizer ID:        "
            f"{route.get('AuthorizerId') or ''}"
        )

        if index < len(routes):
            print()


def print_stages(
    stages,
):
    print()
    print_separator()
    print("STAGES")
    print_separator()

    if not stages:
        print("No stages configured.")
        return

    for index, stage in enumerate(
        stages,
        start=1,
    ):
        print(
            f"[{index}]"
        )

        print(
            f"Stage Name:           "
            f"{stage.get('StageName', '')}"
        )

        print(
            f"Auto Deploy:          "
            f"{stage.get('AutoDeploy', False)}"
        )

        access_log = stage.get(
            "AccessLogSettings",
            {},
        )

        if access_log:
            print(
                f"Access Log ARN:       "
                f"{access_log.get('DestinationArn', '')}"
            )

            print(
                f"Access Log Format:    "
                f"{access_log.get('Format', '')}"
            )
        else:
            print(
                "Access Logging:        disabled"
            )

        route_settings = stage.get(
            "DefaultRouteSettings",
            {},
        )

        print(
            f"Throttle Burst:       "
            f"{route_settings.get('ThrottlingBurstLimit', '')}"
        )

        print(
            f"Throttle Rate:        "
            f"{route_settings.get('ThrottlingRateLimit', '')}"
        )

        if index < len(stages):
            print()


def print_tags(
    tags,
):
    print()
    print_separator()
    print("TAGS")
    print_separator()

    if not tags:
        print("No tags configured.")
        return

    for key in sorted(tags):
        print(
            f"{key}: {tags[key]}"
        )


# ============================================================
# Run
# ============================================================

def run():
    client = create_apigateway_client()

    api = get_api(
        client
    )

    api_id = api.get(
        "ApiId"
    )

    if not api_id:
        raise RuntimeError(
            "API Gateway ApiId is missing."
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

    print_api(
        api
    )

    print_cors(
        api
    )

    print_integrations(
        integrations
    )

    print_routes(
        routes
    )

    print_stages(
        stages
    )

    print_tags(
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

        print(
            "[ERROR] AWS API error: "
            f"{error_code}: "
            f"{error_message}"
        )

        return 1

    except BotoCoreError as error:
        print(
            f"[ERROR] AWS SDK error: {error}"
        )

        return 1

    except RuntimeError as error:
        print(
            f"[ERROR] {error}"
        )

        return 1

    except KeyboardInterrupt:
        print()
        print(
            "[INFO] Interrupted by user."
        )

        return 130

    return 0


if __name__ == "__main__":
    sys.exit(
        main()
    )