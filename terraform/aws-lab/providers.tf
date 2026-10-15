# Credentials come from the environment only: temporary keys of the MFA-protected Admin role,
# exported by the AWS CLI (see README, `aws-lab`). The provider can't prompt for an MFA code itself,
# so it never assumes the role on its own. No access keys or role ARNs in code or tfvars.
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
