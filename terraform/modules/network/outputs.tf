output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the (single) public subnet."
  value       = module.vpc.public_subnets[0]
}
