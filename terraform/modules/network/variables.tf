variable "name" {
  description = "Prefix for resource names, e.g. feedr-dev."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR, /16. Different per environment so they could be peered later without overlaps."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a /16 network, e.g. 10.20.0.0/16."
  }
}
