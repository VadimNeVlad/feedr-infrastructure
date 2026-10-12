# Terraform — AWS lab

A throwaway copy of the production server on EC2: create → configure with Ansible → test → destroy.
Production stays on the OVH VPS (ordered in the OVH panel, DNS managed in Cloudflare by hand);
this stack only creates and destroys AWS resources and never touches production.

Creates: VPC, public subnet, internet gateway, route table, security group (SSH from your IP,
80/443 from anywhere), key pair, one Ubuntu EC2 instance (`t3.small`, encrypted gp3 root volume,
IMDSv2, T3 `standard` credits). No NAT gateway, no load balancer, no Elastic IP.

State is local and git-ignored. All commands run in WSL, from this directory.

## One-time setup

**[AWS console]**
- Root user: MFA on, no access keys. Don't work as root.
- Billing → Budgets → **Zero spend budget** with your email — alert on the first cent.
- IAM Identity Center → enable → create a user for yourself with `AdministratorAccess`
  permission set on this account (later: a narrower set).

**[WSL]** AWS CLI v2 and SSO login (short-lived credentials, nothing stored long-term):

```bash
aws configure sso --profile feedr-lab
```

**[WSL]** A separate SSH key for the lab (not the production `feedr_vps`):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/feedr_aws_lab -C feedr-aws-lab
```

## Run

```bash
# [WSL] every new shell
aws sso login --profile feedr-lab
export AWS_PROFILE=feedr-lab
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
```

```bash
# [WSL]
terraform init
terraform fmt -check && terraform validate
terraform plan -out=tfplan   # expect: 13 to add, 0 to change, 0 to destroy
terraform apply tfplan
terraform output ssh_command
```

Your home IP changes → SSH times out → re-export `TF_VAR_admin_cidr` and `terraform apply`
(only the SSH rule changes).

## Destroy — every time you finish

```bash
# [WSL]
terraform destroy   # expect: 13 to destroy
```

Check that nothing is left (should print nothing):

```bash
# [WSL]
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=feedr Key=Environment,Values=lab \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

## What costs money

On the Free plan everything here is paid from credits ($100–200 for 6 months); the plan cannot
go over them. Roughly per running hour: `t3.small` ~$0.02, public IPv4 $0.005, 20 GiB gp3 a few
cents per day. Forgetting `destroy` for a month ≈ $20 of credits.
