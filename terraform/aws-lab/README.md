# Terraform — AWS lab

A throwaway copy of the production server on EC2: create → configure with Ansible → test → destroy.
Production stays on the OVH VPS (ordered in the OVH panel, DNS managed in Cloudflare by hand);
this stack only creates and destroys AWS resources and never touches production.

Creates: VPC, public subnet, internet gateway, route table, security group (SSH from your IP,
80/443 from anywhere), key pair, one Ubuntu EC2 instance (`t3.small`, encrypted gp3 root volume,
IMDSv2, T3 `standard` credits). No NAT gateway, no load balancer, no Elastic IP.

Region is `eu-north-1` (Stockholm): the AWS Free plan pins the account to a single region.
State is local and git-ignored. All commands run in WSL, from this directory.

## One-time setup

Done once per AWS account, shared by every project in it — not per project.

The Free plan has no AWS Organizations and no IAM Identity Center for account access, and IAM
users get no console sign-in. So access is a CLI-only IAM user that can do exactly one thing —
assume an admin role, and only with MFA:

```
IAM user vadym  (access key; only permission: sts:AssumeRole on Admin)
      │  AssumeRole + MFA code
      ▼
IAM role Admin  (AdministratorAccess; trust: only vadym, only with MFA) → temporary keys, 4 h
```

A leaked access key is useless without the phone.

**[AWS console, root]**
- Root user: MFA on, no access keys. Root is for billing and IAM setup only.
- Billing → Budgets: **Zero spend budget** + a monthly cost budget with credits excluded
  (alerts at 50/80/100 % actual, 100 % forecasted).
- IAM → role `Admin`: trusted entity *This account*, `AdministratorAccess`, max session 8 h.
  Trust policy — only the user, only with MFA:

  ```json
  {
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::<ACCOUNT_ID>:user/vadym" },
    "Action": "sts:AssumeRole",
    "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
  }
  ```

- IAM → user `vadym`, no console access. Inline policy `assume-admin-role`:
  `sts:AssumeRole` on `arn:aws:iam::<ACCOUNT_ID>:role/Admin`. ARNs are case-sensitive — copy the
  role ARN from the console, a typo is a silent `AccessDenied`.
- Access key for `vadym` (use case: CLI).

**[WSL]** AWS CLI v2, profile with the user's key:

```bash
aws configure --profile lab-vadym   # region eu-north-1
```

**[WSL]** MFA for `vadym` — the console has no MFA button for IAM users on the Free plan, so it's
done via the API. Temporarily give `vadym` an inline policy allowing `iam:CreateVirtualMFADevice`
(on `mfa/*`) and `iam:EnableMFADevice` (on `user/${aws:username}`), then:

```bash
aws iam create-virtual-mfa-device --profile lab-vadym --virtual-mfa-device-name vadym-phone \
  --bootstrap-method QRCodePNG --outfile ~/vadym-mfa.png   # scan with an authenticator app
aws iam enable-mfa-device --profile lab-vadym --user-name vadym \
  --serial-number arn:aws:iam::<ACCOUNT_ID>:mfa/vadym-phone \
  --authentication-code1 <code> --authentication-code2 <next code>
rm ~/vadym-mfa.png   # the QR code is the MFA secret
```

Remove the temporary policy afterwards.

**[WSL]** Role profile in `~/.aws/config`:

```ini
[profile lab-admin]
role_arn = arn:aws:iam::<ACCOUNT_ID>:role/Admin
source_profile = lab-vadym
mfa_serial = arn:aws:iam::<ACCOUNT_ID>:mfa/vadym-phone
duration_seconds = 14400
region = eu-north-1
```

Check — the first must print `assumed-role/Admin/...`, the second must fail with `AccessDenied`:

```bash
aws sts get-caller-identity --profile lab-admin
aws ec2 describe-vpcs --profile lab-vadym
```

**[WSL]** The Terraform AWS provider can't prompt for an MFA code, so the CLI assumes the role and
exports the temporary keys into the shell. Add to `~/.bashrc`:

```bash
# AWS lab: assume the Admin role via CLI (asks MFA) and export temporary credentials for Terraform
aws-lab() {
  unset AWS_PROFILE
  export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
  eval "$(aws configure export-credentials --profile lab-admin --format env)" \
    && aws sts get-caller-identity --query Arn --output text
}
```

`AWS_PROFILE` is unset so the keys in the environment are the only source of credentials.

**[WSL]** A separate SSH key for the lab (not the production `feedr_vps`):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/feedr_aws_lab -C feedr-aws-lab
```

## Run

```bash
# [WSL] every new shell, and again when the keys expire (ExpiredToken) after 4 hours
aws-lab
```

```bash
# [WSL]
terraform init
terraform fmt -check && terraform validate
terraform plan -out=tfplan   # expect: 13 to add, 0 to change, 0 to destroy
terraform apply tfplan
terraform output ssh_command
```

Your home IP changes → SSH times out → run `aws-lab` again (refreshes `TF_VAR_admin_cidr`) and
`terraform apply` (only the SSH rule changes).

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

On the Free plan everything here is paid from credits; the plan cannot go over them. Roughly per
running hour: `t3.small` ~$0.02, public IPv4 $0.005, 20 GiB gp3 a few cents per day. Forgetting
`destroy` for a month ≈ $20 of credits.
