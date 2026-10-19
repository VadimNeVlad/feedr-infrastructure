# Unit tests for the network module: `terraform test` from the module directory.
# The AWS provider is mocked — no credentials, no resources, runs in seconds (and in CI).

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
    }
  }
}

variables {
  name = "test"
  cidr = "10.20.0.0/16"
}

run "one_public_subnet_and_no_nat" {
  command = plan

  # Compared element by element: a `[...]` literal is a tuple, the module output is a list,
  # and `==` between different types is always false.
  assert {
    condition     = length(module.vpc.public_subnets_cidr_blocks) == 1 && module.vpc.public_subnets_cidr_blocks[0] == "10.20.1.0/24"
    error_message = "Expected exactly one public subnet, 10.x.1.0/24."
  }

  assert {
    condition     = length(module.vpc.azs) == 1 && module.vpc.azs[0] == "eu-north-1a"
    error_message = "The subnet must be in the first available AZ only."
  }

  assert {
    condition     = length(module.vpc.natgw_ids) == 0
    error_message = "No NAT gateway: it costs ~$35/month even idle."
  }
}

run "rejects_non_16_cidr" {
  command = plan

  variables {
    cidr = "10.20.0.0/24"
  }

  expect_failures = [var.cidr]
}
