# Unit tests for the server module: `terraform test` from the module directory.
# The AWS provider is mocked — no credentials, no resources, runs in seconds (and in CI).
# They pin the security guarantees the module promises, so a refactor can't silently drop one.

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }

  # The IAM policy document renders JSON from its arguments; a mock would return a random string.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name          = "test"
  vpc_id        = "vpc-0123456789abcdef0"
  subnet_id     = "subnet-0123456789abcdef0"
  instance_type = "t3.micro"
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

run "shell_access_only_through_session_manager" {
  command = plan

  # (key_name can't be asserted to be empty: it's a computed attribute, unknown at plan time.)
  assert {
    condition     = aws_instance.server.iam_instance_profile == "test-server"
    error_message = "The instance must have the module's instance profile (SSM Agent needs it)."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.server_ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instance role must have exactly the SSM core policy."
  }
}

run "rejects_non_free_tier_instance_type" {
  command = plan

  variables {
    instance_type = "t3.large"
  }

  expect_failures = [var.instance_type]
}
