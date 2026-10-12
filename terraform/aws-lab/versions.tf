terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The exact version is pinned in .terraform.lock.hcl (committed); this is the allowed range.
      version = "~> 6.68"
    }
  }
}
