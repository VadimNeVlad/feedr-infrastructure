# TFLint: static checks beyond `terraform validate`. Shared by every Terraform directory
# (the pre-commit hook passes this file explicitly). Run `tflint --init` once to download plugins.

config {
  # Also inspect calls to our own modules (../../modules/*); registry modules are not downloaded.
  call_module_type = "local"
}

# Terraform language rules: unused declarations, missing types/descriptions, deprecated syntax...
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: invalid instance types and AMI formats, previous-generation types, missing tags...
# Without deep_check: it would call AWS APIs and need credentials.
plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
