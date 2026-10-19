# One Ubuntu server for the FeedR stack (Docker Compose behind the nginx gateway), with the same
# exposure as production: SSH only from the admin IP, HTTP/HTTPS from anywhere.

# Latest official Ubuntu image, published by Canonical in SSM Parameter Store —
# no hardcoded AMI IDs (they differ per region and go stale).
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/${var.ubuntu_release}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------------------------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------------------------

# A security group sits outside the instance, so Docker's iptables rules cannot bypass it (unlike ufw).
# Rules are separate resources, not inline blocks: the current AWS provider recommendation —
# each rule gets its own ID and tags, and changing one rule doesn't recreate the others.
resource "aws_security_group" "server" {
  name        = "${var.name}-server"
  description = "FeedR server: SSH from admin IP, HTTP/HTTPS from anywhere"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-server"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.server.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.server.id
  description       = "HTTP: ACME challenge and redirect to HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.server.id
  description       = "HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Security groups are stateful: replies to these outgoing connections (apt, GHCR, Let's Encrypt)
# are allowed automatically — unlike OVH's stateless Edge Network Firewall.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.server.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------------------------

resource "aws_key_pair" "server" {
  key_name   = var.name
  public_key = var.ssh_public_key

  tags = {
    Name = var.name
  }
}

resource "aws_instance" "server" {
  # insecure_value: the AMI ID is public; .value is always marked sensitive and hides it in plan.
  ami                    = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.server.id]
  key_name               = aws_key_pair.server.key_name

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
    Name = "${var.name}-server"
  }

  lifecycle {
    # Canonical publishes a new AMI every few weeks; without this, every such release would make
    # plan want to replace the server. A new image is picked up only on a deliberate replace.
    ignore_changes = [ami]
  }
}
