terraform {
  required_version = ">= 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # A module sets only the lower bound it needs; the root (envs/*) pins the exact version.
      version = ">= 6.68"
    }
  }
}
