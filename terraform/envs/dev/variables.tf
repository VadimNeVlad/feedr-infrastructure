variable "region" {
  description = "AWS region. Stockholm: the Free plan pins the account to a single region, others return AccessDenied."
  type        = string
  default     = "eu-north-1"
}

variable "admin_cidr" {
  description = "Your public IP as /32 — the only source allowed to SSH. Pass via TF_VAR_admin_cidr (set by `aws-lab`), not committed."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Public key installed for the default 'ubuntu' user. A separate key for AWS, not the production one."
  type        = string
  default     = "~/.ssh/feedr_aws_lab.pub"
}
