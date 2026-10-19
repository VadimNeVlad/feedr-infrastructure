# Credentials come from the environment only: temporary keys of the MFA-protected Admin role,
# exported by the AWS CLI (`aws-lab`, set up in the aws-platform repository).
provider "aws" {
  region = var.region

  # Every resource gets these tags: who owns it, which environment, that it is safe to destroy.
  # Cost Explorer and Resource Groups can then filter everything by Project / Environment.
  default_tags {
    tags = {
      Project     = "feedr"
      Environment = "dev"
      ManagedBy   = "terraform"
      Repository  = "feedr-infrastructure"
    }
  }
}
