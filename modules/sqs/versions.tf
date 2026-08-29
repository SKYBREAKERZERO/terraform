terraform {
    required_version = "aws"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = ">= 5.0, < 7.0"
        }
    }
}