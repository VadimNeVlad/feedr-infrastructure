# Credentials come from the environment only: temporary keys of the MFA-protected Admin role,
# exported by the AWS CLI (`aws-lab`, set up in the aws-platform repository).
provider "aws" {
  region = var.region

  # Environment = shared: used by every environment and kept between their deploy/destroy cycles.
  default_tags {
    tags = {
      Project     = "feedr"
      Environment = "shared"
      ManagedBy   = "terraform"
      Repository  = "feedr-infrastructure"
    }
  }
}
