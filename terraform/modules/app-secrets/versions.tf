terraform {
  # Ephemeral resources and write-only arguments: Terraform 1.11+.
  required_version = ">= 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # A module sets only the lower bound it needs; the root (envs/*) pins the exact version.
      version = ">= 6.68"
    }
    random = {
      source = "hashicorp/random"
      # Ephemeral random_password: 3.7+.
      version = ">= 3.7"
    }
  }
}
