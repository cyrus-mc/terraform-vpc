/* Query all the availability zones */
data "aws_availability_zones" "get_all" {}

/* find transit gateway (if required) */
data "aws_ec2_transit_gateway" "default" {
  count = local.find_transit_gateway
}

/* create VPC */
resource "aws_vpc" "environment" {
  cidr_block = var.cidr_block

  /* Enable DNS support and DNS hostnames to support private hosted zones */
  enable_dns_support   = var.enable_dns
  enable_dns_hostnames = var.enable_dns

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(var.tags, local.tags, { "vpc" = var.name })
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  for_each = toset(var.secondary_cidr_blocks)

  vpc_id     = aws_vpc.environment.id
  cidr_block = each.value
}

/* create a single internet gateway */
resource "aws_internet_gateway" "main" {
  count = local.enable_internet_access

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags)
}

/*
  Provision NAT Gateway per Availability Zone

  We provisio a single NAT Gateway per availability zone, using the first subnet defined
  for that AZ
*/
resource "aws_eip" "eip" {
  for_each = var.enable_internet_access ? local.public_subnet_per_availability_zone : {}

  tags = merge(var.tags, local.tags, { "Name"              = format("%s.%s", var.name, each.key) },
                                     { "vpc"               = var.name },
                                     { "availability_zone" = each.key })
}

resource "aws_nat_gateway" "ngw" {
  for_each = var.enable_internet_access ? local.public_subnet_per_availability_zone : {}

  allocation_id = aws_eip.eip[each.key].id
  subnet_id     = aws_subnet.public[each.value[0]].id

  tags = merge(var.tags, local.tags, { "Name"              = format("%s.%s", var.name, each.key) },
                                     { "vpc"               = var.name },
                                     { "availability_zone" = each.key })
}

/* create a route table for the public subnet(s) */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name"              = "public" },
                                     { "vpc"               = var.name },
                                     { "availability_zone" = "all" })
}

resource "aws_route" "public" {
  count = local.enable_internet_access

  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route" "public_additional" {
  for_each = local.routes_public

  route_table_id = aws_route_table.public.id

  destination_cidr_block     = each.value.cidr_block
  destination_prefix_list_id = each.value.prefix_list_id

  carrier_gateway_id        = each.value.carrier_gateway_id
  egress_only_gateway_id    = each.value.egress_only_gateway_id
  gateway_id                = each.value.gateway_id
  instance_id               = each.value.instance_id
  local_gateway_id          = each.value.local_gateway_id
  transit_gateway_id        = each.value.transit_gateway_id
  vpc_endpoint_id           = each.value.vpc_endpoint_id
  vpc_peering_connection_id = each.value.vpc_peering_connection_id
}

/* create a route table per Availability Zone for private subnet(s) */
resource "aws_route_table" "private" {
  for_each = toset(local.availability_zones)

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name"              = "private" },
                                     { "vpc"               = var.name },
                                     { "availability_zone" = each.value })
}

resource "aws_route" "private" {
  for_each = var.enable_internet_access ? toset(local.availability_zones) : toset([])

  route_table_id = aws_route_table.private[each.key].id

  /* default route is NAT gateway */
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[each.key].id
}

resource "aws_route" "private_additional" {
  for_each = local.routes_private

  route_table_id = aws_route_table.private[each.value.az].id

  destination_cidr_block     = each.value.cidr_block
  destination_prefix_list_id = each.value.prefix_list_id

  carrier_gateway_id        = each.value.carrier_gateway_id
  egress_only_gateway_id    = each.value.egress_only_gateway_id
  gateway_id                = each.value.gateway_id
  instance_id               = each.value.instance_id
  local_gateway_id          = each.value.local_gateway_id
  transit_gateway_id        = each.value.transit_gateway_id
  vpc_endpoint_id           = each.value.vpc_endpoint_id
  vpc_peering_connection_id = each.value.vpc_peering_connection_id
}


##############################################
#     Private / Public / Custom Subnets      #
##############################################
/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Private subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.environment.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  /* private subnet, no public IPs */
  map_public_ip_on_launch = false

  /* merge all the tags together */
  tags = merge(var.tags,
               lookup(var.private_subnet_tags, each.value.group, lookup(var.private_subnet_tags, "all", {})),
               local.tags, { "Name" = format("private-%d.%s", each.value.index, var.name) })

  depends_on = [ aws_vpc_ipv4_cidr_block_association.this ]
}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Public subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.environment.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  /* instances in the public zone get an IP address */
  map_public_ip_on_launch = var.enable_public_ip

  /* merge all the tags together */
  tags = merge(var.tags,
               lookup(var.public_subnet_tags, each.value.group, lookup(var.private_subnet_tags, "all", {})),
               local.tags, { "Name" = format("public-%d.%s", each.value.index, var.name) })

  depends_on = [ aws_vpc_ipv4_cidr_block_association.this ]
}

##############################################
#    Route Table association resources       #
##############################################

/*
  Associate the public subnet with the above route table

  Dependencies: aws_subnet.public, aws_route_table.public
*/
resource "aws_route_table_association" "public" {
  for_each = local.create_public_subnets ? local.public_subnets : {}

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

/*
  Associate the private subnet(s) with the main VPC route table

  Dependencies: aws_subnet.private, aws_vpc.environment
*/
resource "aws_route_table_association" "private" {
  for_each = local.create_private_subnets ? local.private_subnets : {}

  subnet_id = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}

/* create network ACL (if defined) */
resource "aws_network_acl" "private" {
  count = length(lookup(var.network_acls, "private", [])) > 0 ? 1 : 0

  vpc_id = aws_vpc.environment.id

  subnet_ids = [ for object in aws_subnet.private: object.id ]

  dynamic "egress" {
    for_each = local.private_outbound_network_acls

    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = lookup(egress.value, "cidr_block", aws_vpc.environment.cidr_block)
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  dynamic "ingress" {
    for_each = local.private_inbound_network_acls

    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = lookup(ingress.value, "cidr_block", aws_vpc.environment.cidr_block)
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  tags = merge(var.tags, local.tags)
}

resource "aws_network_acl" "public" {
  count = length(lookup(var.network_acls, "public", [])) > 0 ? 1 : 0

  vpc_id = aws_vpc.environment.id

  subnet_ids = [ for object in aws_subnet.public: object.id ]

  dynamic "egress" {
    for_each = local.public_outbound_network_acls

    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = lookup(egress.value, "cidr_block", aws_vpc.environment.cidr_block)
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  dynamic "ingress" {
    for_each = local.public_inbound_network_acls

    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = lookup(ingress.value, "cidr_block", aws_vpc.environment.cidr_block)
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  tags = merge(var.tags, local.tags)
}
