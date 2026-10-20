output "instance_id" {
  description = "EC2 instance ID — the target of `aws ssm start-session`."
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Public IPv4 for HTTP/HTTPS — changes on every create."
  value       = aws_instance.server.public_ip
}

output "ami_id" {
  description = "Ubuntu AMI the instance was created from."
  value       = aws_instance.server.ami
}

output "role_name" {
  description = "Instance role; attach more policies to it outside the module if the server needs AWS access."
  value       = aws_iam_role.server.name
}
