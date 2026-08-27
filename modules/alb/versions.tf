terraform {
    required_version = ">= 1.8.0"

    required_providers {
        aws = {
            source = "hashcorp/aws"
            version = ">= 5.0,< 7.0"
        }
    }
}