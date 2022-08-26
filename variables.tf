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
  private_subnets_tmp = flatten([ for group, blocks in var.private_subnets: [
                                    for index, subnet in blocks:
                                      { format("%s.%s.%s", group, index, element(local.availability_zones, index)): {
                                          cidr_block: subnet,
                                          # load balance over all available zones
                                          availability_zone: element(local.availability_zones, index),
                                          index: index,
                                          group: group
                                        }
                                      }
                                    ]
                                ])

  private_subnets = { for value in local.private_subnets_tmp:
                        keys(value)[0] => values(value)[0]
                     }

  public_subnets_tmp = flatten([ for group, blocks in var.public_subnets: [
                                   for index, subnet in blocks:
                                     { format("%s.%s.%s", group, index, element(local.availability_zones, index)): {
                                         cidr_block: subnet,
                                         # load balance over all available zones
                                         availability_zone: element(local.availability_zones, index),
                                         index: index,
                                         group: group
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

  /* check if route specified for transit gateway, with blank ID */
  find_transit_gateway = length([ for route in var.routes: true
                                     if lookup(route, "transit_gateway_id", null) == "" ]) > 0 ? 1 : 0

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

  routes_enriched = [ for key, route in var.routes:
                        merge(route, { name:                      lookup(route, "name", key),
                                       cidr_block:                lookup(route, "cidr_block", null),
                                       prefix_list_id:            lookup(route, "prefix_list_id", null),
                                       carrier_gateway_id:        lookup(route, "carrier_gateway_id", null),
                                       egress_only_gateway_id:    lookup(route, "egress_only_gateway_id", null),
                                       gateway_id:                lookup(route, "gateway_id", null),
                                       instance_id:               lookup(route, "instance_id", null),
                                       local_gateway_id:          lookup(route, "local_gateway_id", null),
                                       transit_gateway_id:        lookup(route, "transit_gateway_id", null) == "" ? data.aws_ec2_transit_gateway.default[0].id : lookup(route, "transit_gateway_id", null),
                                       vpc_endpoint_id:           lookup(route, "vpc_endpoint_id", null),
                                       vpc_peering_connection_id: lookup(route, "vpc_peering_connection_id", null) }) ]

  routes_tmp = flatten([ for az in local.availability_zones: [
                   for route in local.routes_enriched:
                     merge(route, { az: az }) ]
                ])

  routes_per_az = { for route in local.routes_tmp: format("%s.%s", route.az, route.name) => route
                      if contains(["all", "private"], lookup(route, "type", "all"))
                  }

  routes_private = { for key, value in local.routes_per_az: key => value }

  routes_public = { for route in local.routes_enriched: route.name => route
                      if contains(["all", "public"], lookup(route, "type", "all"))
                  }


  sg_default_inbound_rules = {
    Default = {
      from_port = 0
      to_port   = 0
      protocol  = -1
      self      = true
    }
  }
  sg_inbound_rules = var.security_group_ingress_rules == {} ? {} : merge(local.sg_default_inbound_rules, var.security_group_ingress_rules)

  sg_default_outbound_rules = {
    Default = {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = [ "0.0.0.0/0" ]
    }
  }
  sg_outbound_rules = var.security_group_egress_rules == {} ? {} : merge(local.sg_default_outbound_rules, var.security_group_egress_rules)


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

variable "cidr_block" {
  type = string
}

variable "secondary_cidr_blocks" {
  type    = map
  default = {}
}

variable "sg_cidr_blocks" {
  default     = []
  type        = list(string)
}

variable "security_group_ingress_rules" { default = null }
variable "security_group_egress_rules"  { default = null }

variable "private_subnets" { default = {} }
variable "public_subnets"  { default = {} }


variable "routes" { default = {} }

/*
  This allows us to add additional tags to the public subnet.

  Needed for Kubernetes, as an example, to tag with KubernetesCluster.
*/
variable "public_subnet_tags"  {
  type    = map(map(string))
  default = {}
}

variable "private_subnet_tags" {
  type    = map(map(string))
  default = {}
}

variable "enable_dns"       { default = true }
variable "enable_public_ip" { default = false }

variable "network_acls" { default = {} }

variable "enable_internet_access" { default = true }

variable "tags" { default = {} }
