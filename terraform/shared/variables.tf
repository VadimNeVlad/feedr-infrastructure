variable "region" {
  description = "AWS region. Stockholm: the Free plan pins the account to a single region, others return AccessDenied."
  type        = string
  default     = "eu-north-1"
}

variable "images_to_keep" {
  description = "How many sha-* tagged images each repository keeps; older ones are deleted. Enough to roll back several releases."
  type        = number
  default     = 10
}
