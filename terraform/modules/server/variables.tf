variable "name" {
  description = "Prefix for resource names, e.g. feedr-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security group in."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t3.small (2 GB) fits the whole stack; t3.micro (1 GB) needs swap and is tight."
  type        = string

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
