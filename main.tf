/* Query all the availability zones */
data "aws_availability_zones" "get_all" {}

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
  count = length(var.secondary_cidr_block)

  vpc_id     = aws_vpc.environment.id
  cidr_block = var.secondary_cidr_block[count.index]
}

/* create a single internet gateway */
resource "aws_internet_gateway" "main" {
  count = local.enable_internet_access

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags)
}

/*
  Provision NAT Gateway per Availability Zone
*/
resource "aws_eip" "eip" {
  count = length(local.availability_zones) * local.enable_internet_access

  tags = merge(var.tags, local.tags, { "Name" = format("%s.%s", var.name,
                                                                local.availability_zones[count.index]) },
                                     { "vpc"    = var.name },
                                     { "region" = local.availability_zones[count.index] })
}

resource "aws_nat_gateway" "ngw" {
  count = length(local.availability_zones) * local.enable_internet_access

  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, local.tags, { "Name" = format("%s.%s", var.name,
                                                                local.availability_zones[count.index]) },
                                     { "vpc"    = var.name },
                                     { "region" = local.availability_zones[count.index] })
}

/* create a route table for the public subnet(s) */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name" = "public" },
                                     { "VPC" = var.name },
                                     { "region" = "all" })
}

resource "aws_route" "public" {
  count = local.enable_internet_access

  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

/* create a route table per Availability Zone for private subnet(s) */
resource "aws_route_table" "private" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name" = "private" },
                                     { "vpc"  = var.name },
                                     { "region" = local.availability_zones[count.index] })
}

resource "aws_route" "private" {
  count = length(local.availability_zones) * local.enable_internet_access

  route_table_id = aws_route_table.private[count.index].id

  /* default route is NAT gateway */
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[count.index].id
}

##############################################
#     Private / Public / Custom Subnets      #
##############################################
/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Private subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

/* only used if list of private subnets to create isn't passed in */
resource "null_resource" "generated_private_subnets" {
  /* create a subnet for each availability zone required */
  count = length(local.availability_zones) * local.generate_subnets

  triggers = {
    cidr_block = cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, length(local.availability_zones) + count.index)
  }
}

resource "aws_subnet" "private" {
  count = length(local.availability_zones) * local.create_private_subnets

  vpc_id = aws_vpc.environment.id

  cidr_block = local.private_subnets[ count.index ]

  /* load balance over all availability zones */
  availability_zone = element(local.availability_zones, count.index)

  /* private subnet, no public IPs */
  map_public_ip_on_launch = false

  /* merge all the tags together */
  tags = merge(var.tags, var.private_subnet_tags, local.tags, { "Name" = format("private-%d.%s", count.index,
                                                                                                 var.name) })
  depends_on = [ aws_vpc_ipv4_cidr_block_association.this ]
}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Public subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

resource "null_resource" "generated_public_subnets" {
  /* create subnet for each availability zone required */
  count = length(local.availability_zones) * local.generate_subnets

  triggers = {
    cidr_block = cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, count.index)
  }
}

resource "aws_subnet" "public" {
  count = length(local.availability_zones) * local.create_public_subnets

  vpc_id = aws_vpc.environment.id

  /* create subnet at the end of the cidr block */
  cidr_block = local.public_subnets[count.index]

  /* load balance over all the availabilty zones */
  availability_zone = element(local.availability_zones, count.index)

  /* instances in the public zone get an IP address */
  map_public_ip_on_launch = var.enable_public_ip

  /* merge all the tags together */
  tags = merge(var.tags, var.public_subnet_tags, local.tags, { "Name" = format("public-%d.%s", count.index,
                                                                                               var.name) })

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
  count = length(local.availability_zones) * local.create_public_subnets

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

/*
  Associate the private subnet(s) with the main VPC route table

  Dependencies: aws_subnet.private, aws_vpc.environment
*/
resource "aws_route_table_association" "private" {
  count = length(local.availability_zones) * local.create_private_subnets

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
  //route_table_id = aws_vpc.environment.main_route_table_id
}

/* create network ACL (if defined) */
resource "aws_network_acl" "main" {
  count = length(var.network_acl_rules) > 0 ? 1 : 0

  vpc_id = aws_vpc.environment.id

  dynamic "egress" {
    for_each = local.outbound_network_acl_rules

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
    for_each = local.inbound_network_acl_rules

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
