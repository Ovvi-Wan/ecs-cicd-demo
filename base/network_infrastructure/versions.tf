terraform {
  backend "s3" {
    bucket       = "ecs-cicd-tutorial-tfstate-270654520169-us-east-1"
    key          = "base/network_infrastructure/dev/terraform.tfstate"
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
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_prefix
      ManagedBy   = "Terraform"
      Environment = var.environment
      Component   = "network_infrastructure"
    }
  }
}
