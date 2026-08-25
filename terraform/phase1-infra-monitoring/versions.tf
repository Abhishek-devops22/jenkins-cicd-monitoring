terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend on purpose: this project is small enough that one state
  # file on disk is fine to start with. If more than one person starts
  # running `terraform apply`, migrate to a shared S3 backend (+ DynamoDB
  # lock table) so state is shared and locked — see README.md, "Growing
  # beyond local state". Don't add that before you actually need it.
}

provider "aws" {
  region = var.aws_region
}
