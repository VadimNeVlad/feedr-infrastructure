output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Public IPv4 — changes on every create. Input for the Ansible inventory."
  value       = aws_instance.server.public_ip
}

output "ami_id" {
  description = "Ubuntu AMI the instance was created from."
  value       = aws_instance.server.ami
}

output "ssh_command" {
  description = "Connect as the AMI's default user."
  value       = "ssh -i ${trimsuffix(pathexpand(var.ssh_public_key_path), ".pub")} ubuntu@${aws_instance.server.public_ip}"
}
