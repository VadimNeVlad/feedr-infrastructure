output "registry" {
  description = "ECR registry host — for `docker login` and image references."
  value       = split("/", values(aws_ecr_repository.this)[0].repository_url)[0]
}

output "cloudinary_secret_arn" {
  description = "Secrets Manager secret with the Cloudinary API key and secret (value set by hand)."
  value       = aws_secretsmanager_secret.cloudinary.arn
}

output "cloudinary_cloud_name_parameter" {
  description = "Parameter Store name holding the Cloudinary cloud name."
  value       = aws_ssm_parameter.cloudinary_cloud_name.name
}

output "repository_urls" {
  description = "Image repository URLs by name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
