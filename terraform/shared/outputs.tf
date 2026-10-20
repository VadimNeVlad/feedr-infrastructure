output "registry" {
  description = "ECR registry host — for `docker login` and image references."
  value       = split("/", values(aws_ecr_repository.this)[0].repository_url)[0]
}

output "repository_urls" {
  description = "Image repository URLs by name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
