# Terraform — FeedR on AWS

Throwaway copies of the production server on EC2: create → configure with Ansible → test → destroy.
Production stays on the OVH VPS (ordered in the OVH panel, DNS managed in Cloudflare by hand);
nothing here touches production.

AWS access (IAM user + MFA-protected `Admin` role, the `aws-lab` shell function) and the shared
Terraform state bucket live in the separate **aws-platform** repository.

## Layout

```
modules/            how things are built — shared by every environment
├── network/        VPC, one public subnet, internet gateway, locked default SG
│                   (wraps terraform-aws-modules/vpc, pinned)
└── server/         security group (SSH from your IP, 80/443 from anywhere), key pair,
                    Ubuntu EC2 (encrypted gp3, IMDSv2, T3 standard credits)
envs/               what differs — one directory = one root module = one state
├── dev/            feedr-dev,  10.20.0.0/16, t3.micro
└── prod/           feedr-prod, 10.30.0.0/16, t3.small
```

No NAT gateway, no load balancer, no Elastic IP. Region `eu-north-1` (the Free plan pins the
account to a single region). Each environment keeps its state in the shared bucket under
`feedr-infrastructure/envs/<env>/terraform.tfstate`.

A change to a module reaches every environment: apply it to `dev` first, then `prod`.

## One-time setup

**[WSL]** A separate SSH key for AWS (not the production `feedr_vps`):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/feedr_aws_lab -C feedr-aws-lab
```

## Run

All commands in WSL, from `envs/<env>/`.

```bash
aws-lab   # every new shell, and again on ExpiredToken (4 hours); also refreshes TF_VAR_admin_cidr
```

```bash
terraform init
terraform fmt -recursive -check ../.. && terraform validate
terraform plan -out=tfplan   # expect: 16 to add, 0 to change, 0 to destroy
terraform apply tfplan
terraform output -raw ssh_command
```

Your home IP changes → SSH times out → `aws-lab` again and `terraform apply` (only the SSH rule changes).

## Destroy — every time you finish

```bash
terraform destroy
```

Check that nothing is left (should print nothing; the tagging API lags a few minutes,
`aws ec2 describe-*` is the final word):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=feedr \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

## What costs money

Everything is paid from Free plan credits; the plan cannot go over them. Roughly per running hour:
`t3.micro` ~$0.01, `t3.small` ~$0.02, public IPv4 $0.005, 20 GiB gp3 a few cents per day.
Forgetting `destroy` for a month ≈ $10–20 of credits per environment.
