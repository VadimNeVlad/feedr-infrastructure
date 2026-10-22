# prod: the copy sized like production (t3.small, 2 GB), changed only after dev.
# What differs between environments lives here (name, CIDR, sizes); how things are built
# lives in ../../modules, shared by every environment.

locals {
  name = "feedr-prod"
}

module "network" {
  source = "../../modules/network"

  name = local.name
  cidr = "10.30.0.0/16"
}

module "server" {
  source = "../../modules/server"

  name          = local.name
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_id
  instance_type = "t3.small"
}

module "secrets" {
  source = "../../modules/app-secrets"

  environment = "prod"
}
