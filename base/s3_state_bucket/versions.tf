terraform {
  # Initially use local state. After the bucket exists, fill in its name,
  # uncomment the backend block below, and run terraform init -migrate-state.
  backend "s3" {
    bucket       = "ecs-cicd-tutorial-tfstate-270654520169-us-east-1"
    key          = "base/s3_state_bucket/terraform.tfstate"
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
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Project   = var.project_prefix
      ManagedBy = "Terraform"
      Component = "s3_state_bucket"
    }
  }
}
