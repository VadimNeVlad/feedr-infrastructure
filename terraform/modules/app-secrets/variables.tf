variable "environment" {
  description = "Environment name, part of the secret names: feedr/<environment>/..."
  type        = string
}

variable "jwt_secret_version" {
  description = "Bump to generate and store a new JWT secret (rotation). Every user is logged out."
  type        = number
  default     = 1
}
