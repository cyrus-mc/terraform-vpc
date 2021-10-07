################################################
#        Local Variable defintions             #
################################################
locals {
  /* Select the zones based on whether they are passed in, or query all zones */
  availability_zones = (length(var.availability_zones) == 0
                                                            ? data.aws_availability_zones.get_all.names
                                                            : var.availability_zones)

  create_public_subnets = true
  create_private_subnets = true

  /* helper variable for use in count */
  enable_internet_access = var.enable_internet_access ? 1 : 0

  /*
    convert:

      [
        {
          group: ID
          cidr_blocks: [ ... ]
        }
      ]

    to:

     {
       ID.index.availability_zone = {
         availability_zone = "availability_zone"
         cidr_block        = "..."
         index             = #
         group             = ID
       }
     }

    ex:

    Assuming two availability zones us-west-2a and us-west-2b

      [
        {
          group: "primary"
          cidr_blocks: [ "10.0.0.0/24", "10.0.1.0/24" ]
        },
        {
          group: "secondary"
          cidr_blocks: [ "10.0.2.0/24", "10.0.3.0/24" ]
        }
      ]

      =>

      {
        primary.0.us-west-2a = {
          availability_zone = "us-west-2a"
          cidr_block        = "10.0.0.0/24"
          index             = 0
          group             = "primary"
        }
        primary.1.us-west-2b = {
          availability_zone = "us-west-2b"
          cidr_block        = "10.0.1.0/24"
          index             = 1
          group             = "primary"
        }
        secondary.0.us-west-2a = {
          availability_zone = "us-west-2a"
          cidr_block        = "10.0.2.0/24"
          index             = 0
          group             = "secondary"
        }
        secondary.1.us-west-2b = {
          availability_zone = "us-west-2b"
          cidr_block        = "10.0.3.0/24"
          index             = 0
          group             = "secondary"
        }
      }

  */
  private_subnets_tmp = flatten([ for groups in var.private_subnets: [
                                    for index, subnet in groups.cidr_blocks:
                                      { format("%s.%s.%s", groups.group, index, element(local.availability_zones, index)): {
                                          cidr_block: subnet,
                                          # load balance over all available zones
                                          availability_zone: element(local.availability_zones, index),
                                          index: index,
                                          group: groups.group
                                        }
                                      }
                                    ]
                                ])

  private_subnets = { for value in local.private_subnets_tmp:
                        keys(value)[0] => values(value)[0]
                     }

  public_subnets_tmp = flatten([ for groups in var.public_subnets: [
                                    for index, subnet in groups.cidr_blocks:
                                      { format("%s.%s.%s", groups.group, index, element(local.availability_zones, index)): {
                                          cidr_block: subnet,
                                          # load balance over all available zones
                                          availability_zone: element(local.availability_zones, index),
                                          index: index,
                                          group: groups.group
                                        }
                                      }
                                    ]
                                ])

  public_subnets = { for value in local.public_subnets_tmp:
                       keys(value)[0] => values(value)[0]
                   }


  /* create map of availability zones to subnets/cidr blocks */
  public_subnet_per_availability_zone = { for key, value in local.public_subnets:
                                            value.availability_zone => key... }

  /*
    create list of private/public ingress/egress ACL rules
  */
  private_inbound_network_acls_tmp = [ for value in lookup(var.network_acls, "private", []): value
                                              if lookup(value, "type", "n/a") == "ingress" ]
  private_inbound_network_acls     = [ for index, value in local.private_inbound_network_acls_tmp: merge(value, { rule_no: ((index + 1) * 100) }) ]
  private_outbound_network_acls_tmp = [ for value in lookup(var.network_acls, "private", []): value
                                              if lookup(value, "type", "n/a") == "egress" ]
  private_outbound_network_acls     = [ for index, value in local.private_outbound_network_acls_tmp: merge(value, { rule_no: ((index + 1) * 100)   }) ]

  public_inbound_network_acls_tmp = [ for value in lookup(var.network_acls, "public", []): value
                                                if lookup(value, "type", "n/a") == "ingress" ]
  public_inbound_network_acls     = [ for index, value in local.public_inbound_network_acls_tmp: merge(value, { rule_no: ((index + 1) * 100)   }) ]
  public_outbound_network_acls_tmp = [ for value in lookup(var.network_acls, "public", []): value
                                                if lookup(value, "type", "n/a") == "egress" ]
  public_outbound_network_acls     = [ for index, value in local.public_outbound_network_acls_tmp: merge(value, { rule_no: ((index + 1) * 100) }) ]

  /* default tags */
  tags = {
    Name       = format("%s", var.name)
    built-with = "terraform"
  }
}

output test { value = local.private_subnets }

variable "name" {}

variable "availability_zones" {
  default     = []
  type        = list(string)
}

variable "cidr_block" {
  type = string
}

variable "secondary_cidr_blocks" {
  type    = list
  default = []
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

variable "network_acls" { default = {} }

variable "enable_internet_access" { default = true }

variable "tags" { default = {} }
