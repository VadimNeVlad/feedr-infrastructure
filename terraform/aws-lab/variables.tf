variable "region" {
  description = "AWS region. London, next to the production VPS."
  type        = string
  default     = "eu-west-2"
}

variable "instance_type" {
  description = "EC2 instance type. t3.small (2 GB) fits the whole stack; t3.micro (1 GB) needs swap and is tight."
  type        = string
  default     = "t3.small"

  # Guardrail: only Free Tier eligible x86 types (accounts created after 2025-07-15).
  # x86 only — the application images are built for amd64, so no t4g (ARM).
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Use a Free Tier eligible x86 type: t3.micro or t3.small."
  }
}

variable "ubuntu_release" {
  description = "Ubuntu LTS release, same as production."
  type        = string
  default     = "26.04"
}

variable "root_volume_size" {
  description = "Root EBS volume size, GiB. Free Tier covers up to 30 GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 10 && var.root_volume_size <= 30
    error_message = "root_volume_size must be between 10 and 30 GiB."
  }
}

variable "admin_cidr" {
  description = "Your public IP as /32 — the only source allowed to SSH. Pass via TF_VAR_admin_cidr, not committed."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a single IPv4 address in /32 form, e.g. 203.0.113.10/32."
  }
}

variable "ssh_public_key_path" {
  description = "Public key installed for the default 'ubuntu' user. A separate key for the lab, not the production one."
  type        = string
  default     = "~/.ssh/feedr_aws_lab.pub"
}
