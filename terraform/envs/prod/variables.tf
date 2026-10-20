variable "region" {
  description = "AWS region. Stockholm: the Free plan pins the account to a single region, others return AccessDenied."
  type        = string
  default     = "eu-north-1"
}
