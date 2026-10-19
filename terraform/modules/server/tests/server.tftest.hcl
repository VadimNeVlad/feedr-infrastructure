# Unit tests for the server module: `terraform test` from the module directory.
# The AWS provider is mocked — no credentials, no resources, runs in seconds (and in CI).
# They pin the security guarantees the module promises, so a refactor can't silently drop one.

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }
}

variables {
  name           = "test"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_id      = "subnet-0123456789abcdef0"
  instance_type  = "t3.micro"
  admin_cidr     = "203.0.113.10/32"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyOnly test"
}

run "instance_is_hardened" {
  command = plan

  assert {
    condition     = aws_instance.server.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required (http_tokens = required)."
  }

  assert {
    condition     = aws_instance.server.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Metadata hop limit must be 1, so containers can't reach the metadata service."
  }

  assert {
    condition     = aws_instance.server.root_block_device[0].encrypted
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = aws_instance.server.credit_specification[0].cpu_credits == "standard"
    error_message = "T3 credits must be standard: unlimited bills for extra CPU."
  }
}

run "ssh_is_open_only_to_admin_ip" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh.cidr_ipv4 == var.admin_cidr
    error_message = "SSH must be allowed only from admin_cidr."
  }
}

run "rejects_non_free_tier_instance_type" {
  command = plan

  variables {
    instance_type = "t3.large"
  }

  expect_failures = [var.instance_type]
}

run "rejects_ssh_from_a_whole_network" {
  command = plan

  variables {
    admin_cidr = "0.0.0.0/0"
  }

  expect_failures = [var.admin_cidr]
}
