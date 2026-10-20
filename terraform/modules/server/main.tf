# One Ubuntu server for the FeedR stack (Docker Compose behind the nginx gateway): HTTP/HTTPS from
# anywhere, and no SSH at all — shell access goes through AWS Systems Manager Session Manager.

# Latest official Ubuntu image, published by Canonical in SSM Parameter Store —
# no hardcoded AMI IDs (they differ per region and go stale). The SSM Agent is preinstalled.
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/${var.ubuntu_release}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------------------------------------------------------------------------------------------
# Instance identity: how the server itself gets AWS credentials (an instance profile — temporary
# keys from the metadata service, rotated by AWS; never access keys on the disk).
# ---------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "server_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name               = "${var.name}-server"
  description        = "EC2 instance role of ${var.name}: Session Manager access."
  assume_role_policy = data.aws_iam_policy_document.server_trust.json
}

# The minimum the SSM Agent needs: register the instance and open Session Manager channels.
# Nothing else — the application on the server gets no AWS permissions through this role.
resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 attaches roles through an instance profile, a container for exactly one role.
resource "aws_iam_instance_profile" "server" {
  name = "${var.name}-server"
  role = aws_iam_role.server.name
}

# ---------------------------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------------------------

# A security group sits outside the instance, so Docker's iptables rules cannot bypass it (unlike ufw).
# Rules are separate resources, not inline blocks: the current AWS provider recommendation —
# each rule gets its own ID and tags, and changing one rule doesn't recreate the others.
#
# No SSH rule: Session Manager connections are outbound from the SSM Agent (HTTPS to the SSM
# endpoints), so nothing listens for shell access from the internet.
resource "aws_security_group" "server" {
  name        = "${var.name}-server"
  description = "FeedR server: HTTP/HTTPS from anywhere, no SSH (Session Manager)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-server"
  }
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

# Security groups are stateful: replies to these outgoing connections (apt, GHCR, Let's Encrypt,
# SSM endpoints) are allowed automatically — unlike OVH's stateless Edge Network Firewall.
#
# Accepted: apt mirrors, GHCR and Let's Encrypt have no fixed IP ranges, so outbound traffic can't
# be pinned to addresses in a security group. Real restriction needs an egress proxy or a NAT
# with a firewall (and VPC endpoints for AWS services) — beyond this lab.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.server.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------------------------

resource "aws_instance" "server" {
  # insecure_value: the AMI ID is public; .value is always marked sensitive and hides it in plan.
  ami                    = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name

  # T3 defaults to "unlimited": once CPU credits run out, AWS bills for the extra CPU.
  # "standard" throttles instead — no surprise charges.
  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 only (session tokens): blocks SSRF-style theft of instance metadata — and with it of
  # the instance role's keys. Hop limit 1: containers behind Docker's bridge (one extra hop) can't
  # reach the metadata service, so the application never sees the instance role.
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
