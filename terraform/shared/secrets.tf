# Configuration and secrets shared by every environment, kept between their deploy/destroy cycles.
#
# Secrets Manager for secrets (encrypted, access per secret through IAM, versioned, rotation-ready;
# $0.40/secret/month), Parameter Store for plain configuration (free).

# Cloudinary credentials come from a third party: Terraform creates the secret, but never knows
# its value — a person puts it in once (see README). Neither git nor the Terraform state ever
# contains it.
#
# Accepted (trivy AWS-0098): encrypted with the AWS managed key aws/secretsmanager instead of a
# customer KMS key ($1/month) — key-level policies and audit aren't needed with one admin role.
#trivy:ignore:AWS-0098
resource "aws_secretsmanager_secret" "cloudinary" {
  name        = "feedr/cloudinary"
  description = "Cloudinary API credentials for the FeedR backend: JSON {\"api_key\", \"api_secret\"}. Value set by hand."

  # A deleted secret can be restored for this many days; recreating the same name is blocked
  # meanwhile. Short: this is a lab, the value can be re-entered from Cloudinary.
  recovery_window_in_days = 7
}

# Not a secret: the cloud name is part of every public image URL (res.cloudinary.com/<name>/...).
resource "aws_ssm_parameter" "cloudinary_cloud_name" {
  name        = "/feedr/cloudinary/cloud_name"
  description = "Cloudinary cloud name for the FeedR backend."
  type        = "String"
  value       = var.cloudinary_cloud_name
}
