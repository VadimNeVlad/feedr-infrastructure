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

output "session_command" {
  description = "Shell on the server through Session Manager (needs the session-manager-plugin)."
  value       = "aws ssm start-session --target ${module.server.instance_id}"
}
