terraform {
  # The pipeline supplies key through terraform init -backend-config.
  backend "s3" {
    bucket       = "ecs-cicd-tutorial-tfstate-270654520169-us-east-1"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_version = "= 1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.61.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "ecs-cicd-tutorial"
      Application = var.application
      ManagedBy   = "Terraform"
    }
  }
}
