output "instance_id" {
  description = "EC2 instance ID."
  value       = module.server.instance_id
}

output "public_ip" {
  description = "Public IPv4 — changes on every create. Input for the Ansible inventory."
  value       = module.server.public_ip
}

output "ami_id" {
  description = "Ubuntu AMI the instance was created from."
  value       = module.server.ami_id
}

output "ssh_command" {
  description = "Connect as the AMI's default user."
  value       = "ssh -i ${trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")} ubuntu@${module.server.public_ip}"
}
