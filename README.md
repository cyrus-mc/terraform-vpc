# Amazon Web Services VPC

[![Build Status](http://jenkins.dat.com/buildStatus/icon?job=DevOps/Terraform/Modules/tf-module-vpc/master)](http://jenkins.services.dat.internal/job/DevOps/job/Terraform/job/Modules/job/tf-module-vpc/)

Terraform module used to setup a VPC according to the following structure: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html

Official AWS documentation: https://docs.aws.amazon.com/vpc/latest/userguide/getting-started-ipv4.html

## Requirements
- - - -

This module requires:

   -  [AWS Provider](https://github.com/terraform-providers/terraform-provider-aws) `>= 1.17.0`
   -  [Null Resource Provider](https://github.com/terraform-providers/terraform-provider-null) `>= 1.0.0`

### Inputs
- - - -

This module takes the following inputs:

  Name                 | Description   | Type          | Default
  -------------------- | ------------- | ------------- | -------------
  `name`               | tag:Name value used for created resources. | string | -
  `availability_zones` | List of availability zones to provision subnets for. | list | `[]`
  `cidr_block`         | CIDR block to allow to the VPC | string | -
  `cidr_block_bits`    | Bits to extend cidr_block by for subnets. Only used if public_subnets and private_subnets are not supplied. | string | `8`
  `sg_cidr_blocks`     | CIDR block to allow inbound on default security group | list | `[]`
  `private_subnets`    | List of cidr blocks for private subnets. | list | `[]`
  `public_subnets`     | List of cidr blocks for public subnets. | list | `[]`
  `public_subnet_tags` | Map of tags to apply to public subnets. | map | `{}`
  `private_subnet_tags` | Map of tags to apply to private subnets. | map | `{}`
  `enable_dns` | A boolean flag to enable/disable DNS support and DNS hostnames. | boolean | `true`
  `enable_public_ip` | A boolean flag to enable/disable assignment of public IP to instances launched in `public_subnets` | boolean | `false`
  `create_vgw` | A boolean indicating whether to create a VPC VPN Gateway and corresponding EC2 VPN connection. | boolean | `true`
  `customer_gateway_id` | The ID of the customer gateway (required if create_vgw = true). | string | `""`
  `govcloud` | Set to true when creating VPC in govCloud (which doesn't have support for NAT gateway). | boolean | `false`
  `key_name` | EC2 SSH key for NAT instance (required and only used when govcloud = true). | string | `""`
  `peering_info` | List of VPC, by tag:Name, to peer. VPC's must exist in the same account. Use https://bitbucket.org/dat/tf-module-vpc-peering/src/master/ instead. | list | `[]`
  `route53_zone` | Name of the route53 zone to create and associate with this VPC. | string | `""`
  `tags`               | Map of tags to apply to all resources | map | `{}`

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
  `nat_instance_id`    | Instance ID of the NAT instance (govcloud = true only). | string


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
  public_subnet_tags {
    tag1 = "value1"
  }
  /* add some additional tags to private subnets */
  private_subnet_tags {
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

  /* add some additional tags to public subnets */
  public_subnet_tags {
    tag1 = "value1"
  }
  /* add some additional tags to private subnets */
  private_subnet_tags {
    tag2 = "value2"
  }
}

```
