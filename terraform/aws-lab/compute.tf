# Latest official Ubuntu image, published by Canonical in SSM Parameter Store —
# no hardcoded AMI IDs (they differ per region and go stale).
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/${var.ubuntu_release}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "lab" {
  key_name   = "feedr-lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "server" {
  # insecure_value: the AMI ID is public; .value is always marked sensitive and hides it in plan.
  ami                    = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.server.id]
  key_name               = aws_key_pair.lab.key_name

  # T3 defaults to "unlimited": once CPU credits run out, AWS bills for the extra CPU.
  # "standard" throttles instead — no surprise charges.
  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 only (session tokens): blocks SSRF-style theft of instance metadata.
  # Hop limit 1: containers behind Docker's bridge (one extra hop) can't reach the metadata service.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "feedr-lab-server"
  }

  lifecycle {
    # Canonical publishes a new AMI every few weeks; without this, every such release would make
    # plan want to replace the server. A new image is picked up only on a deliberate replace.
    ignore_changes = [ami]
  }
}
