terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The exact version is pinned in .terraform.lock.hcl (committed); this is the allowed range.
      version = "~> 6.68"
    }
  }

  # Shared state bucket from the aws-platform repository (bootstrap stack); one key per
  # environment, so dev and prod never touch each other's state. Backend blocks can't use variables.
  backend "s3" {
    bucket = "tfstate-593469034324-eu-north-1"
    key    = "feedr-infrastructure/envs/prod/terraform.tfstate"
    region = "eu-north-1"

    use_lockfile = true
    encrypt      = true
  }
}
