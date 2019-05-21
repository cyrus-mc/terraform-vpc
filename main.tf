/*
  Query all the availability zones
*/
data "aws_availability_zones" "get_all" {}

/*
  Create the environment VPC.

  Dependencies: none
*/

################################################
#          Virtual Private Cloud               #
################################################
resource "aws_vpc" "environment" {
  cidr_block = var.cidr_block

  /*
    Enable DNS support and DNS hostnames to support private hosted zones
  */
  enable_dns_support   = var.enable_dns
  enable_dns_hostnames = var.enable_dns

  lifecycle {
    prevent_destroy = "true"
  }

  tags = merge(var.tags, local.tags)
}

/*
  Modify the default security group created as part of the VPC
*/
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.environment.id

  /* only want to do this once if rules are supplied */
  #count = 2

  /* allow all traffic from within the VPC */
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = var.sg_cidr_blocks
    self        = true
  }

  /* allow all outbound traffic */
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = merge(var.tags, local.tags)
}

##############################################
#          Internet Gateway                  #
##############################################
/*
  Create the internet gateway for this VPC

  Dependencies: aws_vpc.environment
*/
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags)
}

##############################################
# Network Address Translation (NAT)  Gateway #
##############################################
/*
  Provision a NAT gateway in each availability zone

  Dependencies: aws_eip.eip, aws_subnet.public
*/
resource "aws_eip" "eip" {
  count = length(local.availability_zones)
}

resource "aws_nat_gateway" "ngw" {
  count = length(local.availability_zones)

  allocation_id = aws_eip.eip[ count.index ].id
  subnet_id     = aws_subnet.public[ count.index ].id
}

###############################################
#     Route Table Creation / Modification     #
###############################################
/*
  Route table with default route being the internet gateway

  Dependencies: aws_vpc.environment, aws_internet_gateway.gw
*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name" = format("public.%s", var.name) })
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table" "private" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags, { "Name" = format("public.%s", var.name) })
}

resource "aws_route" "private" {
  count = length(local.availability_zones)

  route_table_id = aws_route_table.private[ count.index ].id

  /* default route is NAT gateway */
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[ count.index ].id
}

/*
  Main route table for the VPC with default route being the NAT instance

  Dependencies: aws_vpc.environment, aws_net_gateway.ngw
*/
//resource "aws_route" "main" {
  /* main route table associated with our VPC */
 // route_table_id = aws_vpc.environment.main_route_table_id

  //destination_cidr_block = "0.0.0.0/0"

  /* main route table associated with our VPC */
  //nat_gateway_id = aws_nat_gateway.ngw[0].id
//}

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
  count = length(local.availability_zones)

  triggers = {
    cidr_block = cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, length(local.availability_zones) + count.index)
  }
}

resource "aws_subnet" "private" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.environment.id

  cidr_block = local.private_subnets[ count.index ]

  /* load balance over all availability zones */
  availability_zone = element(local.availability_zones, count.index)

  /* private subnet, no public IPs */
  map_public_ip_on_launch = false

  /* merge all the tags together */
  tags = merge(var.tags, var.private_subnet_tags, local.tags, { "Name" = format("private-%d.%s", count.index, var.name) })
}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Public subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

resource "null_resource" "generated_public_subnets" {
  /* create subnet for each availability zone required */
  count = length(local.availability_zones)

  triggers = {
    cidr_block = cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, count.index)
  }
}

resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.environment.id

  /* create subnet at the end of the cidr block */
  cidr_block = local.public_subnets[ count.index ]

  /* load balance over all the availabilty zones */
  availability_zone = element(local.availability_zones, count.index)

  /* instances in the public zone get an IP address */
  map_public_ip_on_launch = var.enable_public_ip

  /* merge all the tags together */
  tags = merge(var.tags, var.public_subnet_tags, local.tags, { "Name" = format("public-%d.%s", count.index, var.name) })
}

/*
  Create a Virtual Private Gateway

  Dependencies: aws_vpc.environment
*/
resource "aws_vpn_gateway" "vpn_gw" {
  count = (var.create_vgw ? 1 : 0)

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags)
}

/*
  Create the VPN connection

  Dependencies: aws_vpn_gateway.vpn_gw
*/
resource "aws_vpn_connection" "vpn" {
  count = (var.create_vgw ? 1 : 0)

  vpn_gateway_id = aws_vpn_gateway.vpn_gw[0].id

  customer_gateway_id = var.customer_gateway_id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = merge(var.tags, local.tags)
}

##############################################
#    Route Table association resources       #
##############################################

/*
  Associate the public subnet with the above route table

  Dependencies: aws_subnet.public, aws_route_table.public
*/
resource "aws_route_table_association" "public" {
  count = length(local.availability_zones)

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

/*
  Associate the private subnet(s) with the main VPC route table

  Dependencies: aws_subnet.private, aws_vpc.environment
*/
resource "aws_route_table_association" "private" {
  count = length(local.availability_zones)

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
  //route_table_id = aws_vpc.environment.main_route_table_id
}

/* create private route53 zone */
resource "aws_route53_zone" "vpc" {
  count = local.create_zone
  name  = var.route53_zone

  vpc_id = aws_vpc.environment.id

  tags = merge(var.tags, local.tags)
}

