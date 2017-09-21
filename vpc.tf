/*
  Create the environment VPC.

  Dependencies: none
*/
resource "aws_vpc" "environment" {

  cidr_block = "${var.cidr_block}"

  /*
    Enable DNS support and DNS hostnames to support private hosted zones
  */
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  /* prevent deletion so we don't lose VPN connection setup */
#  lifecycle {
#    prevent_destroy = "true"
#  }

  tags {
    builtWith = "terraform"
    Name      = "${var.environment}"
  }

}

/*
  Modify the default security group created as part of the VPC
*/
resource "aws_default_security_group" "default" {

  vpc_id = "${aws_vpc.environment.id}"

  /* allow all traffic from within the VPC */
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ "${var.cidr_block}" ]
  }

}

/*
  Create a Virtual Private Gateway

  Dependencies: aws_vpc.environment
*/
resource "aws_vpn_gateway" "vpn_gw" {

  vpc_id = "${aws_vpc.environment.id}"

  tags {
    builtWith = "terraform"
    Name      = "${var.environment}"
  }

}

/*
  Create the VPN connection

  Dependencies: aws_vpn_gateway.vpn_gw
*/
resource "aws_vpn_connection" "vpn" {

  vpn_gateway_id      = "${aws_vpn_gateway.vpn_gw.id}"

  customer_gateway_id = "${var.customer_gateway_id}"
  type                = "ipsec.1"
  static_routes_only  = true

  tags {
    builtWith = "terraform"
    Name      = "${var.environment}"
  }

}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Private subnet (this is a single point of failure)

  Dependencies: aws_vpc.environment
*/
resource "aws_subnet" "private" {

  count  = "${length(data.aws_availability_zones.all.names)}"
  vpc_id = "${aws_vpc.environment.id}"

  /* create subnet at the specified location (cidr_block, cidr_block_bits, cidr_block_start) */
  cidr_block = "${cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, format("%d", var.cidr_block_start + ( count.index * - 1)))}"

  /* load balance over all availability zones */
  availability_zone = "${element(data.aws_availability_zones.all.names, count.index)}"

  /* private subnet, no public IPs */
  map_public_ip_on_launch = false

  tags {
    builtWith = "terraform"
    Name      = "private-${count.index}.${var.environment}"
  }

}

/*
  http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario2.html

  Public subnet (this is a single point of failure) 

  Dependencies: aws_vpc.environment
*/
resource "aws_subnet" "public" {

  vpc_id = "${aws_vpc.environment.id}"

  /* create subnet at the end of the cidr block */
  cidr_block        = "${cidrsubnet(aws_vpc.environment.cidr_block, var.cidr_block_bits, var.cidr_block_end)}"
  /* place in first availability zone */
  availability_zone	= "${element(data.aws_availability_zones.all.names, 1)}"

  /* instances in the public zone get an IP address */
  map_public_ip_on_launch	= true

  tags {
    builtWith = "terraform"
    Name      = "public.${var.environment}"
  }

}

/*
  Create the internet gateway for this VPC

  Dependencies: aws_vpc.environment
*/
resource "aws_internet_gateway" "gw" {

  vpc_id = "${aws_vpc.environment.id}"

  tags {
    builtWith  = "terraform"
    Name       = "${var.environment}"
  }
}

/*
  Route table with default route being the internet gateway

  Dependencies: aws_vpc.environment, aws_internet_gateway.gw
*/
resource "aws_route_table" "public" {

  vpc_id = "${aws_vpc.environment.id}"

  /* default route to internet gateway */
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    builtWith = "terraform"
    Name      = "public.${var.environment}"
  }

}

/*
	Main route table for the VPC with default route being the NAT instance

	Dependencies: aws_vpc.environment, aws_net_gateway.ngw
*/
resource "aws_route" main {

  /* only required if deploying into non-GovCloud region */
  count = "${1 - var.aws_govcloud}"

  /* main route table associated with our VPC */
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

  destination_cidr_block = "0.0.0.0/0"
  /* main route table associated with our VPC */
  nat_gateway_id         = "${aws_nat_gateway.ngw.id}"

}

resource "aws_route" "main-govcloud" {

  /* only required if deploying into AWS GovCloud region */
  count = "${var.aws_govcloud}"

  /* main route table associated with our VPC */
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${aws_instance.nat_instance.id}"

}


/*
  Provision a NAT gateway

  Dependencies: aws_eip.eip, aws_subnet.public

  Not applicable for AWS GovCloud region  
*/
resource "aws_eip" "eip" { 

  count = "${1 - var.aws_govcloud}"

}
resource "aws_nat_gateway" "ngw" {

  count         = "${1 - var.aws_govcloud}"

  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.public.id}"

}

/*
  Associate the public subnet with the above route table

  Dependencies: aws_subnet.public, aws_route_table.public
*/
resource "aws_route_table_association" "public" {

  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"

}

/*
  Associate the private subnet(s) with the main VPC route table

  Dependencies: aws_subnet.private, aws_vpc.environment
*/
resource "aws_route_table_association" "private" {

  count = "${length(data.aws_availability_zones.all.names)}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

}

/*
  VPC Security Groups

  NAT Instance
*/
resource "aws_security_group" "nat-instance" {

  /* only required if deploying into AWS GovCloud region */
  count = "${var.aws_govcloud}"

  name = "nat-instance-${var.environment}"

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

  /*
    Define egress rules
  */
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

}
