import os
import sys
import boto3
from botocore.exceptions import BotoCoreError, ClientError

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

LAMBDA_FUNCTION_NAME = os.getenv(
    "LAMBDA_FUNCTION_NAME",
)

EXPECTED_FUNCTION_NAME = (
    LAMBDA_FUNCTION_NAME
    if LAMBDA_FUNCTION_NAME
    else f"{PROJECT_NAME}-{ENVIRONMENT}-function"
)

def create_lambda_client():
    return boto3.client(
        "lambda",
        region_name=AWS_REGION,
        endpoint_url=LOCALSTACK_ENDPOINT,
    )

def get_functions(
    client,
):
    functions = []
    marker = None

    while True:
        kwargs = {}

        if marker:
            kwargs["Marker"] = marker

        response = client.list_functions(
            **kwargs
        )

        functions.extend(
            response.get(
                "Functions",
                [],
            )
        )

        marker = response.get(
            "NextMarker"
        )

        if not marker:
            break

    return functions

def get_function_name(
        client
):
    functions = get_functions(
        client
    )

    for function in functions:
        function_name = function.get(
            "FunctionName"
        )

        if (
            function_name
            == EXPECTED_FUNCTION_NAME
        ):
            return function_name

    raise RuntimeError(
        "Lambda function not found: "
        f"{EXPECTED_FUNCTION_NAME}"
    )

def get_function_configuration(
    client,
    function_name,
):
    return client.get_function_configuration(
        FunctionName=function_name,
    )


def get_function_details(
    client,
    function_name,
):
    return client.get_function(
        FunctionName=function_name,
    )

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
    function_name,
):
    try:
        response = (
            client
            .get_function_concurrency(
                FunctionName=function_name,
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

def print_separator(
        character="=",
):
    print(
        character * 70
    )

def format_bool(
        value,
):
    return str(
        bool(value)
    ).lower()

def print_identity(
    configuration,
):
    print_separator()
    print("LAMBDA FUNCTION")
    print_separator()

    print(
        f"Name:                 "
        f"{configuration.get('FunctionName', '')}"
    )

    print(
        f"ARN:                  "
        f"{configuration.get('FunctionArn', '')}"
    )

    print(
        f"Description:          "
        f"{configuration.get('Description') or ''}"
    )

    print(
        f"Package Type:         "
        f"{configuration.get('PackageType', '')}"
    )

    print(
        f"State:                "
        f"{configuration.get('State', '')}"
    )

    print(
        f"State Reason:         "
        f"{configuration.get('StateReason') or ''}"
    )

    print(
        f"Last Update Status:   "
        f"{configuration.get('LastUpdateStatus', '')}"
    )

    print(
        f"Last Modified:        "
        f"{configuration.get('LastModified', '')}"
    )

def print_runtime(
    configuration,
):
    print()
    print_separator()
    print("RUNTIME")
    print_separator()

    print(
        f"Runtime:              "
        f"{configuration.get('Runtime', '')}"
    )

    print(
        f"Handler:              "
        f"{configuration.get('Handler', '')}"
    )

    architectures = configuration.get(
        "Architectures",
        [],
    )

    print(
        f"Architectures:        "
        f"{', '.join(architectures) if architectures else 'none'}"
    )

    print(
        f"Role ARN:             "
        f"{configuration.get('Role', '')}"
    )
