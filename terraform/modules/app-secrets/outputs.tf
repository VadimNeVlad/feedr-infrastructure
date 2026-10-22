output "jwt_secret_arn" {
  description = "ARN of the JWT secret — referenced (not copied) by whatever runs the backend."
  value       = aws_secretsmanager_secret.jwt.arn
}
