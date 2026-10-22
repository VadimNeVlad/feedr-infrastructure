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
├── app-secrets/    per-environment generated secrets (JWT) — never stored in the state
└── server/         security group (80/443 from anywhere, no SSH), instance role for
                    Session Manager, Ubuntu EC2 (encrypted gp3, IMDSv2, T3 standard credits)
shared/             kept between deploy/destroy cycles, used by every environment:
                    ECR repositories, Cloudinary secret (see shared/README.md)
envs/               what differs — one directory = one root module = one state
├── dev/            feedr-dev,  10.20.0.0/16, t3.micro
└── prod/           feedr-prod, 10.30.0.0/16, t3.small
```

No NAT gateway, no load balancer, no Elastic IP. Region `eu-north-1` (the Free plan pins the
account to a single region). Each environment keeps its state in the shared bucket under
`feedr-infrastructure/envs/<env>/terraform.tfstate`.

A change to a module reaches every environment: apply it to `dev` first, then `prod`.

## Shell access: Session Manager, no SSH

The server has no SSH port, no key pair and no allowed admin IP. A shell is opened through AWS
Systems Manager: the SSM Agent on the server keeps an outbound HTTPS connection to AWS, and
`aws ssm start-session` reaches it through that — authorised by IAM (the MFA-protected `Admin`
role) and recorded in CloudTrail.

**[WSL]** One-time: the Session Manager plugin for the AWS CLI (official package from AWS):

```bash
curl -fsSLo /tmp/session-manager-plugin.deb \
  https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb && session-manager-plugin --version
```

## Run

All commands in WSL, from `envs/<env>/`.

```bash
aws-lab   # every new shell, and again on ExpiredToken (4 hours)
```

```bash
terraform init
terraform fmt -recursive -check ../.. && terraform validate
terraform plan -out=tfplan   # expect: 19 to add, 0 to change, 0 to destroy
terraform apply tfplan
eval "$(terraform output -raw session_command)"   # the agent needs 1–2 minutes after boot
```

## Destroy — every time you finish

```bash
terraform destroy
```

Check that nothing is left (should print nothing; the tagging API lags a few minutes,
`aws ec2 describe-*` is the final word):

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=feedr Key=Environment,Values=dev,prod \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

## What costs money

Everything is paid from Free plan credits; the plan cannot go over them. Roughly per running hour:
`t3.micro` ~$0.01, `t3.small` ~$0.02, public IPv4 $0.005, 20 GiB gp3 a few cents per day.
Forgetting `destroy` for a month ≈ $10–20 of credits per environment.
