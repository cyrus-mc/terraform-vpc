# Amazon Web Services VPC

Terraform module used to setup a VPC according to the following structure: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html

Official AWS documentation: https://docs.aws.amazon.com/vpc/latest/userguide/getting-started-ipv4.html

## Requirements
- - - -

This module requires:

   -  [Terraform](https://github.com/hashicorp/terraform) `>= 1.0`
   -  [AWS Provider](https://github.com/terraform-providers/terraform-provider-aws) `>= 2.10.0`
   -  [Null Resource Provider](https://github.com/terraform-providers/terraform-provider-null) `>= 2.1.0`

### Inputs
- - - -

This module takes the following inputs:

  Name                 | Description   | Type          | Default
  -------------------- | ------------- | ------------- | -------------
  `name`               | tag:Name value used for created resources. | string | -
  `availability_zones` | List of availability zones to provision subnets for. | list | `[]`
  `cidr_block`         | CIDR block to allow to the VPC | string | -
  `secondary_cidr_blocks` | Secondary CIDR block(s) to attch to VPC | list | `[]`
  `sg_cidr_blocks`     | CIDR block to allow inbound on default security group | list | `[]`
  `network_acls`  | Map of public and private of network ACL rules (https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | list | `{}`
  `private_subnets`    | List of subnet groups to create private subnets from. | list | `[]`
  `public_subnets`     | List of subnet groups to create public subnets from. | list | `[]`
  `public_subnet_tags` | Map of tags to apply to public subnets. | map | `{}`
  `private_subnet_tags` | Map of tags to apply to private subnets. | map | `{}`
  `enable_dns` | A boolean flag to enable/disable DNS support and DNS hostnames. | boolean | `true`
  `enable_public_ip` | A boolean flag to enable/disable assignment of public IP to instances launched in `public_subnets` | boolean | `false`
  `enable_internet_access` | A boolean flag to enable/disable creation of NAT and Internet gateway resources | boolean | `true`
  `routes` | List of additional routes to add to route tables (see below) | list | `[]`
  `tags`               | Map of tags to apply to all resources | map | `{}`

#### Routes

Additional routes to be added to either/both of the `public` or `private` route tables through input variable `routes`.

Input `routes` is a list of maps with the following structure:

```

  {
    type = "private|public|all"
    name = "..."
    cidr_block = "..."
    prefix_list_id = "..."
    carrier_gateway_id = "..."
    egress_only_gateway_id = "..."
    gateway_id = "..."
    instance_id = "..."
    local_gateway_id = "..."
    transit_gateway_id = "..."
    vpc_endpoint_id = "..."
    vpc_peering_connection_id = "..."
  }


```

Where `type` specifies the route table to add the route to. Default is `all`.

Where only one of `cidr_block` or `prefix_list_id` can be specified.

Where only one of `carrier_gateway_id`, `egress_only_gateway_id`, `gateway_id`, `instance_id`, `local_gateway_id`, `transit_gateway_id`, `vpc_endpoint_id` or `vpc_peering_connection_id` can be specified. If value specified is `""` the module will attempt to determine the relevant value (currently only supported for `transit_gateway_id`).


#### Subnets

The module allows creating subnet `groups`. A subnet group is a logical grouping of subnets (e.g: EKS subnets).

e.g:

```hcl

  private_subnets = [
    {
      id: "primary"
      cidr_blocks: [ "10.36.8.0/24", "10.36.9.0/24" ]
    },
    {
      id: "eks"
      cidr_blocks: [ "10.36.10.0/24", "10.36.11.0/24" ]
    }
  ]

```

All `cidr_blocks` specified must fall within the VPC `cidr_block` or `secondary_cidr_blocks`.

#### Internet Access

When `enable_internet_access` is set to `true` module will provision Internet Gateway and NAT Gateway resources. For the purposes of NAT Gateway(s) a single NAT gateway per availability_zone will be created.

e.g:

```hcl

  availability_zones = [ "us-west-2a", "us-west-2b", "us-west-2c" ]

  enable_internet_access = true

  public_subnets = [
    {
      id: "primary"
      cidr_blocks = [ "10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24" ]
    },
    {
      id: "secondary"
      cidr_blocks = [ "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24" ]
    }
  ]

```

Given the above input subnet group `primary` will create subnets in all 3 availability zones as will subnet group `secondary`. The NAT gateway resources will be provisioned in subnet group `primary` subnets as those listed first.

#### Network ACL

Specified either `public` or `private` Acls when defining `network_acls` to assign the Acl to either the `public` or `private` subnets. When defining rules you must specifiy whether it is an `ingress` or `egress` rule.

Rules are ordered in the order in which they are defined, meaning that you do not need to define `rule_no` as it will be implied based off the order.

If you omit a value for `cidr_block` the CIDR block of the VPC will be used.

e.g:

```hcl

  network_acl = {
    public = [
      {
        type      = "ingress"
        protocol  = "tcp"
        action    = "allow"
        from_port = 80
        to_port   = 80
      },
      {
        type      = "egress"
        protocol  = "tcp"
        action    = "allow"
        from_port = 443
        to_port   = 443
      }
    ],
    private = [
      ...
    ]
  }

```

### Ouputs
- - - -

This module exposes the following outputs:

  Name          | Description   | Type
  ------------- | ------------- | -------------
  `vpc_id` | The ID of the VPC. | string
  `vpc_main_rt_id` | The ID of the main route table associated with this VPC. | string
  `vpc_cidr_block` | The CIDR block of the VPC. | string
  `prvt_subnet_id` | The ID(s) of the private subnet(s). | list
  `public_subnet_id` | The ID(s) of the public subnet(s). | list
  `prvt_subnet_cidr` | The CIDR block of the private subnet(s). | list
  `public_subnet_cidr` | The CIDR block of the public subnet(s). | list

## Usage
- - - -

Create VPC in us-west-2a and us-west-2b and specify subnet details.

```hcl

module "vpc" {
  source = "git::ssh://git@bitbucket.org/dat/tf-module-vpc.git?ref=master"

  name = "vpc1"

  availability_zones = [ "us-west-2a", "us-west-2b" ]

  cidr_block      = "10.36.8.0/22"
  private_subnets = [ "10.36.10.0/24", "10.36.11.0/24" ]
  public_subnets  = [ "10.36.8.0/24", "10.36.9.0/24" ]

  /* add some additional tags to public subnets */
  public_subnet_tags = {
    tag1 = "value1"
  }
  /* add some additional tags to private subnets */
  private_subnet_tags = {
    tag2 = "value2"
  }
}

```

Create VPC in us-west-2a and us-west-2b and dynamically create private and public subnets.

```hcl

module "vpc-dynamic" {
  source = "git::ssh://git@bitbucket.org/dat/tf-module-vpc.git?ref=master"

  name = "vpc-dynamic"

  availability_zones = [ "us-west-2a", "us-west-2b" ]

  cidr_block      = "10.36.8.0/22"
  /* number of bits to extend VPC cidr block for subnets (/24) */
  cidr_block_bits = "2"

  /* create network ACL(s) */
  network_acl_rules = {
    private = [
      {
        type      = "ingress"
        protocol  = "tcp"
        action    = "allow"
        from_port = 80
        to_port   = 80
      },
      {
        type      = "egress"
        protocol  = "tcp"
        action    = "allow"
        from_port = 443
        to_port   = 443
      }
    ]
  }

  /* add route to private tables for traffic 10.0.0.0/8
     to transit gateway (auto-discovered) */
  routes = [
    {
      type = "private"
      name = "transit"
      transit_gateway_id = ""
      cidr_block = "10.0.0.0/8"
    }
  ]

  /* add some additional tags to public subnets */
  public_subnet_tags = {
    tag1 = "value1"
  }
  /* add some additional tags to private subnets */
  private_subnet_tags = {
    tag2 = "value2"
  }
}

```
