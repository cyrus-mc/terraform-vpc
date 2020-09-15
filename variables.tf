################################################
#        Local Variable defintions             #
################################################
locals {
  /* Select the zones based on whether they are passed in, or query all zones */
  availability_zones = (length(var.availability_zones) == 0
                                                            ? data.aws_availability_zones.get_all.names
                                                            : var.availability_zones)

  generate_subnets = var.cidr_block_bits == "" ? 0 : 1
  /* Use passed in public subnets or generate */
  private_subnets = (length(var.private_subnets) == 0
                                                      ? (local.generate_subnets == 0 ? [] : null_resource.generated_private_subnets.*.triggers.cidr_block)
                                                      : var.private_subnets)
  public_subnets  = (length(var.public_subnets) == 0
                                                     ? (local.generate_subnets == 0 ? [] : null_resource.generated_private_subnets.*.triggers.cidr_block)
                                                     : var.public_subnets)

   create_public_subnets  = length(local.public_subnets) == 0 ? 0 : 1
   create_private_subnets = length(local.private_subnets) == 0 ? 0 : 1


  inbound_network_acl_rules_tmp = [ for value in var.network_acl_rules: value
                                      if lookup(value, "type", "n/a") == "ingress" ]
  inbound_network_acl_rules     = [ for index, value in local.inbound_network_acl_rules_tmp: merge(value, { rule_no: ((index + 1) * 100) }) ]

  outbound_network_acl_rules_tmp = [ for value in var.network_acl_rules: value
                                       if lookup(value, "type", "n/a") == "egress" ]
  outbound_network_acl_rules =     [ for index, value in local.outbound_network_acl_rules_tmp: merge(value, { rule_no: ((index + 1) * 100) }) ]

  enable_internet_access = var.enable_internet_access ? 1 : 0

  /* default tags */
  tags = {
    Name       = format("%s", var.name)
    built-with = "terraform"
  }
}

variable "name" {}

variable "availability_zones" {
  default     = []
  type        = list(string)
}

variable "cidr_block"      {}
variable "cidr_block_bits" { default = "" }

variable "secondary_cidr_block" {
  default = []
  type = list(string)
}

variable "sg_cidr_blocks" {
  default     = []
  type        = list(string)
}

variable "private_subnets" { default = [] }
variable "public_subnets"  { default = [] }

/*
  This allows us to add additional tags to the public subnet.

  Needed for Kubernetes, as an example, to tag with KubernetesCluster.
*/
variable "public_subnet_tags"  { default = {} }
variable "private_subnet_tags" { default = {} }

variable "enable_dns"       { default = true }
variable "enable_public_ip" { default = false }

variable "network_acl_rules" { default = [] }

variable "enable_internet_access" { default = true }

variable "tags" { default = {} }
