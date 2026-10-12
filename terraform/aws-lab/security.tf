# Same exposure as production: SSH only from the admin IP, HTTP/HTTPS from anywhere.
# A security group sits outside the instance, so Docker's iptables rules cannot bypass it (unlike ufw).
# Rules are separate resources, not inline blocks: the current AWS provider recommendation —
# each rule gets its own ID and tags, and changing one rule doesn't recreate the others.

resource "aws_security_group" "server" {
  name        = "feedr-lab-server"
  description = "FeedR lab server: SSH from admin IP, HTTP/HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "feedr-lab-server"
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
