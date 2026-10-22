# Module: app-secrets

Per-environment secrets that Terraform generates: the backend's JWT signing secret in Secrets
Manager (`feedr/<environment>/jwt`). The value comes from an ephemeral `random_password` and is
written with the write-only `secret_string_wo`, so it never appears in the plan or the state.
No recovery window: environments are destroyed and recreated all the time.

Secrets provided by people (Cloudinary) live in `terraform/shared`, the database password will be
managed by RDS itself.

```hcl
module "secrets" {
  source = "../../modules/app-secrets"

  environment = "dev"
}
```

Rotation: set `jwt_secret_version = 2` (and so on) and apply — a new random value is stored.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
