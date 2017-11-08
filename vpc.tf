/*
  Create the environment VPC.

  Dependencies: none
*/

################################################
#          Virtual Private Cloud               #
################################################
resource "aws_vpc" "environment" {

  cidr_block = "${var.cidr_block}"

  /*
    Enable DNS support and DNS hostnames to support private hosted zones
  */
  enable_dns_support   = "${var.enable_dns}"
  enable_dns_hostnames = "${var.enable_dns}"

  lifecycle {
    prevent_destroy = "true"
  }

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}"

}


/*
  Modify the default security group created as part of the VPC
*/
resource "aws_default_security_group" "default" {

  vpc_id = "${aws_vpc.environment.id}"

  /* only want to do this once if rules are supplied */
  #count = 2

  /* allow all traffic from within the VPC */
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ "${var.sg_cidr_blocks}" ]
    self = true
  }

  /* allow all outbound traffic */
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}"

}

##############################################
#          Internet Gateway                  #
##############################################
/*
  Create the internet gateway for this VPC

  Dependencies: aws_vpc.environment
*/
resource "aws_internet_gateway" "gw" {

  vpc_id = "${aws_vpc.environment.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}",

}

##############################################
# Network Address Translation (NAT)  Gateway #
##############################################
/*
  Provision a NAT gateway

  Dependencies: aws_eip.eip, aws_subnet.public

  Not applicable for AWS GovCloud region
*/
resource "aws_eip" "eip" {

  count = "${1 - var.govcloud}"

}

resource "aws_nat_gateway" "ngw" {

  count         = "${1 - var.govcloud}"

  allocation_id = "${aws_eip.eip.id}"
  #subnet_id     = "${aws_subnet.public.id}"
  subnet_id      = "${element(aws_subnet.public.*.id, 0)}"


}

###############################################
#     Route Table Creation / Modification     #
###############################################
/*
  Route table with default route being the internet gateway

  Dependencies: aws_vpc.environment, aws_internet_gateway.gw
*/
resource "aws_route_table" "public" {

  vpc_id = "${aws_vpc.environment.id}"

  tags = "${merge(var.tags, map("Name", format("public.%s", var.name)), map("builtWith", "terraform"))}",

}

resource "aws_route" "public-igw" {

  route_table_id = "${aws_route_table.public.id}"

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"

}

/*
  Main route table for the VPC with default route being the NAT instance

  Dependencies: aws_vpc.environment, aws_net_gateway.ngw
*/
resource "aws_route" main {

  /* only required if deploying into non-GovCloud region */
  count = "${1 - var.govcloud}"

  /* main route table associated with our VPC */
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

  destination_cidr_block = "0.0.0.0/0"
  /* main route table associated with our VPC */
  nat_gateway_id         = "${aws_nat_gateway.ngw.id}"

}

resource "aws_route" "main-govcloud" {

  /* only required if deploying into AWS GovCloud region */
  count = "${var.govcloud}"

  /* main route table associated with our VPC */
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${aws_instance.nat_instance.id}"

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
  count = "${length(local.availability_zones)}"

  triggers {
    cidr_block = "${cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, length(local.availability_zones) + count.index)}"
  }

}

resource "aws_subnet" "private" {

  count  = "${length(local.availability_zones)}"
  vpc_id = "${aws_vpc.environment.id}"

  cidr_block = "${element(local.private_subnets, count.index)}"

  /* load balance over all availability zones */
  availability_zone = "${element(local.availability_zones, count.index)}"

  /* private subnet, no public IPs */
  map_public_ip_on_launch = false

  /* merge all the tags together */
  tags = "${merge(var.tags, var.private_subnet_tags, map("Name", format("private-%d.%s", count.index, var.name)), map("builtWith", "terraform"))}"

}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Public subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/

resource "null_resource" "generated_public_subnets" {

  /* create subnet for each availability zone required */
  count = "${length(local.availability_zones)}"

  triggers {
   cidr_block = "${cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, count.index)}"
  }

}
resource "aws_subnet" "public" {

  count  = "${length(local.availability_zones)}"
  vpc_id = "${aws_vpc.environment.id}"

  /* create subnet at the end of the cidr block */
  cidr_block        = "${element(local.public_subnets, count.index)}"

  /* load balance over all the availabilty zones */
  availability_zone = "${element(local.availability_zones, count.index)}"

  /* instances in the public zone get an IP address */
  map_public_ip_on_launch = "${var.enable_public_ip}"

  /* merge all the tags together */
  tags = "${merge(var.tags, var.public_subnet_tags, map("Name", format("public.%s", var.name)), map("builtWith", "terraform"))}"

}

resource "aws_subnet" "kubernetes" {

  count = "${var.enable_kubernetes * length(local.availability_zones)}"
  vpc_id = "${aws_vpc.environment.id}"

  cidr_block        = "${cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, length(local.availability_zones) * 2 + count.index)}"
  availability_zone = "${element(local.availability_zones, count.index)}"

  map_public_ip_on_launch = false

  /* merge all the tags together */
  tags = "${merge(var.tags, var.public_subnet_tags, map("Name", format("kubernetes-%d.%s", count.index, var.name)), map("builtWith", "terraform"), map("KubernetesCluster", "${var.name}"))}"


}


/*
  Create a Virtual Private Gateway

  Dependencies: aws_vpc.environment
*/
resource "aws_vpn_gateway" "vpn_gw" {

  count = "${var.create_vgw}"

  vpc_id = "${aws_vpc.environment.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}"

}

/*
  Create the VPN connection

  Dependencies: aws_vpn_gateway.vpn_gw
*/
resource "aws_vpn_connection" "vpn" {

  count = "${var.create_vgw}"

  vpn_gateway_id      = "${aws_vpn_gateway.vpn_gw.id}"

  customer_gateway_id = "${var.customer_gateway_id}"
  type                = "ipsec.1"
  static_routes_only  = true

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}"

}

##############################################
#    Route Table association resources       #
##############################################

/*
  Associate the public subnet with the above route table

  Dependencies: aws_subnet.public, aws_route_table.public
*/
resource "aws_route_table_association" "public" {

  count          = "${length(local.availability_zones)}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"

}

/*
  Associate the private subnet(s) with the main VPC route table

  Dependencies: aws_subnet.private, aws_vpc.environment
*/
resource "aws_route_table_association" "private" {

  count = "${length(local.availability_zones)}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

}

/*
  Associate the kubernetes subnet(s) (created conditionally) with main VPC
  route table

  Dependencies: aws_subnet.kubernetes, aws_vpc.environment
*/
resource "aws_route_table_association" "kubernetes" {

  count = "${var.enable_kubernetes * length(local.availability_zones)}"

  /* grab each subnet created */
  subnet_id      = "${element(aws_subnet.kubernetes.*.id, count.index)}"
  route_table_id = "${aws_vpc.environment.main_route_table_id}"
}

/*
  VPC Security Groups

  NAT Instance
*/
resource "aws_security_group" "nat-instance" {

  /* only required if deploying into AWS GovCloud region */
  count = "${var.govcloud}"

  name = "nat-instance-${var.name}"

  description = "Define inbound and outbound traffic for NAT instance"

  /* link to the correct VPC */
  vpc_id = "${aws_vpc.environment.id}"

  /*
    Define ingress rules (only allow from our VPC)
  */
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "${aws_vpc.environment.cidr_block}" ]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  /*
    Define egress rules
  */
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = "${merge(var.tags, map("Name", format("%s", var.name)), map("builtWith", "terraform"))}",


}

/*
  Setup any peering requested
*/
resource "aws_vpc_peering_connection" "requestor" {

  count = "${length(var.peering_info)}"

  peer_vpc_id = "${element(data.aws_vpc.peering.*.id, count.index)}"
  vpc_id      = "${aws_vpc.environment.id}"

  accepter {
    allow_remote_vpc_dns_resolution = "${var.enable_dns}"
  }

  requester {
    allow_remote_vpc_dns_resolution = "${var.enable_dns}"
  }

  /* auto-accept the peering request */
  auto_accept = true

  tags {
    Name = "${var.name}:${element(var.peering_info, count.index)}"
  }

}

resource "aws_route" "peer-main" {

  count = "${length(var.peering_info)}"

  /* update only the main route table */
  route_table_id            = "${aws_vpc.environment.main_route_table_id}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requestor.id}"
  destination_cidr_block    = "${element(data.aws_vpc.peering.*.cidr_block, count.index)}"

  depends_on = [ "aws_vpc_peering_connection.requestor" ]

}

resource "aws_route" "peer-secondary" {

  count = "${length(var.peering_info)}"

  /* update only the main route table */
  route_table_id            = "${element(data.aws_route_table.peering.*.id, count.index)}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requestor.id}"
  destination_cidr_block    = "${aws_vpc.environment.cidr_block}"

  depends_on = [ "aws_vpc_peering_connection.requestor" ]

}
