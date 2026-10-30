terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State is kept locally in this folder for now (terraform.tfstate, git-ignored).
  # Later you can move it to an S3 backend so CI can run Terraform too.
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "portfolio"
      ManagedBy = "terraform"
    }
  }
}
