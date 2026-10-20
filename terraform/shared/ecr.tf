# Container registry for FeedR's own images. One repository per image, shared by every
# environment: the same image (same digest) is promoted dev → prod, never rebuilt per environment.

locals {
  repositories = toset([
    "feedr-backend",
    "feedr-backend-migrate",
    "feedr-frontend",
  ])
}

# Accepted (trivy AWS-0033): images are encrypted with AES256 (S3-managed keys) instead of a
# customer KMS key — a KMS key costs $1/month and adds key-level audit nobody reads yet.
#trivy:ignore:AWS-0033
resource "aws_ecr_repository" "this" {
  for_each = local.repositories

  name = each.key

  # A tag, once pushed, always points to the same image: sha-05d46d4 deployed today is the same
  # bytes as in a rollback next month. Pushing an existing tag fails instead of silently replacing it.
  image_tag_mutability = "IMMUTABLE"

  # Basic scanning (free): every pushed image is checked for known OS-package CVEs;
  # results in the console and `aws ecr describe-image-scan-findings`.
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Storage is billed per GB-month: without cleanup every image ever pushed stays forever.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Untagged layers left by failed or replaced pushes"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the last ${var.images_to_keep} releases"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["sha-*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.images_to_keep
        }
        action = { type = "expire" }
      },
    ]
  })
}
