# Module: server

One Ubuntu EC2 server for the FeedR stack: HTTP/HTTPS from anywhere, no SSH — shell access only
through Session Manager (instance role with `AmazonSSMManagedInstanceCore`, no key pair, no port 22).
Hardened by default: IMDSv2 with hop limit 1, encrypted gp3 root volume, T3 `standard` credits,
AMI from Canonical's SSM parameter (ignored after creation).

```hcl
module "server" {
  source = "../../modules/server"

  name          = "feedr-dev"
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_id
  instance_type = "t3.micro"
}
```

Tests: `terraform init && terraform test` in this directory (mocked AWS provider, no credentials).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.16 |
| aws | >= 6.68 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | 6.69.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_instance.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_security_group.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ssm_parameter.ubuntu_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| admin\_cidr | The only source allowed to SSH, a single IPv4 address as /32. | `string` | n/a | yes |
| instance\_type | EC2 instance type. t3.small (2 GB) fits the whole stack; t3.micro (1 GB) needs swap and is tight. | `string` | n/a | yes |
| name | Prefix for resource names, e.g. feedr-dev. | `string` | n/a | yes |
| ssh\_public\_key | Public key (file contents) installed for the default 'ubuntu' user. The module reads no files itself. | `string` | n/a | yes |
| subnet\_id | Public subnet for the instance. | `string` | n/a | yes |
| vpc\_id | VPC to create the security group in. | `string` | n/a | yes |
| root\_volume\_size | Root EBS volume size, GiB. Free Tier covers up to 30 GiB. | `number` | `20` | no |
| ubuntu\_release | Ubuntu LTS release, same as production. | `string` | `"26.04"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| ami\_id | Ubuntu AMI the instance was created from. |
| instance\_id | EC2 instance ID. |
| public\_ip | Public IPv4 — changes on every create. Input for the Ansible inventory. |
<!-- END_TF_DOCS -->
