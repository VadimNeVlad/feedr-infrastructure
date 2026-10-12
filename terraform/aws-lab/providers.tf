# Credentials come from the environment only: AWS_PROFILE pointing to an IAM Identity Center (SSO)
# profile with short-lived credentials. No access keys in code, tfvars or ~/.aws/credentials.
provider "aws" {
  region = var.region

  # Every resource gets these tags: who owns it and that it is safe to destroy.
  # Cost Explorer and Resource Groups can then filter everything by Project / Environment.
  default_tags {
    tags = {
      Project     = "feedr"
      Environment = "lab"
      ManagedBy   = "terraform"
      Repository  = "feedr-infrastructure"
    }
  }
}
