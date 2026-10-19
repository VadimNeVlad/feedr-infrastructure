# Module: network

Our network standard around `terraform-aws-modules/vpc` (pinned): one VPC, one public subnet
(`10.x.1.0/24`) in the first availability zone, internet gateway, no NAT gateway, DNS on,
default security group taken over with no rules. Environments pass only a name and a `/16` CIDR.

```hcl
module "network" {
  source = "../../modules/network"

  name = "feedr-dev"
  cidr = "10.20.0.0/16"
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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| vpc | terraform-aws-modules/vpc/aws | 6.7.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cidr | VPC CIDR, /16. Different per environment so they could be peered later without overlaps. | `string` | n/a | yes |
| name | Prefix for resource names, e.g. feedr-dev. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| public\_subnet\_id | ID of the (single) public subnet. |
| vpc\_id | VPC ID. |
<!-- END_TF_DOCS -->
