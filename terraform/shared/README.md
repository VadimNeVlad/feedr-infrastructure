# Terraform — shared (FeedR)

Project resources used by every environment and kept between their deploy/destroy cycles:

- ECR repositories `feedr-backend`, `feedr-backend-migrate`, `feedr-frontend`: immutable tags,
  scan on push, lifecycle (untagged after 1 day, last 10 `sha-*` releases kept).

State: `feedr-infrastructure/shared/terraform.tfstate` in the shared bucket. Tagged
`Environment = shared`, so the "nothing left" check after destroying `dev`/`prod` doesn't list it.

```bash
# [WSL] from this directory, after aws-lab
terraform init
terraform plan -out=tfplan   # first time: 6 to add
terraform apply tfplan
```

Images get here from GHCR with `scripts/ecr-mirror.sh <sha-tag>` (a stand-in for CI pushing to
ECR, which needs GitHub OIDC — not available on the Free plan).

Destroying this stack fails while repositories contain images (`force_delete` is off on purpose):
delete the images first.
