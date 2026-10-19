# Our network standard, wrapped around the community VPC module: the wrapper decides the
# settings every environment must have (no NAT, locked default security group, DNS on),
# environments only pass a name and a CIDR.

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # Exact version: upgrades are deliberate (read the CHANGELOG, then plan every environment).
  version = "6.7.3"

  name = var.name
  cidr = var.cidr

  # One AZ, one public subnet (10.x.1.0/24): a lab, not high availability.
  # Production would spread subnets over 2–3 AZs.
  azs                     = [data.aws_availability_zones.available.names[0]]
  public_subnets          = [cidrsubnet(var.cidr, 8, 1)]
  map_public_ip_on_launch = true

  # No NAT gateway: ~$35/month even idle, and nothing private needs outbound internet yet.
  enable_nat_gateway = false

  enable_dns_support   = true
  enable_dns_hostnames = true

  # Take over the default security group and leave it with no rules, so nothing attached
  # to it by accident is reachable (CIS AWS Foundations benchmark). No rules is the module default.
  manage_default_security_group = true
  default_security_group_name   = "${var.name}-default-deny"

  # VPC Flow Logs (who talked to whom at the network level) — off for now: shipping them to
  # CloudWatch costs per GB. To try in stage 6.
  enable_flow_log = false
}
