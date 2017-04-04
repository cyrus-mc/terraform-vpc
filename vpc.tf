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
  #lifecycle {
  #  prevent_destroy = "true"
  #}

  tags {
    builtWith = "terraform"
    Name      = "${var.environment}"
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

  customer_gateway_id = "cgw-859d469b"
  type                = "ipsec.1"
  static_routes_only  = true

  tags {
    builtWith = "terraform"
    Name      = "${var.environment}"
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
  cidr_block        = "${cidrsubnet(aws_vpc.environment.cidr_block, 8, 255)}"
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
	Main route table for the VPC with default route being the NAT gateway

	Dependencies: aws_vpc.environment, aws_net_gateway.ngw
*/
resource "aws_route" "main" {

  /* main route table associated with our VPC */
  route_table_id = "${aws_vpc.environment.main_route_table_id}"

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.ngw.id}"

}

/*
  Provision a NAT gateway

  Dependencies: aws_eip.eip, aws_subnet.public
*/
resource "aws_eip" "eip" { }
resource "aws_nat_gateway" "ngw" {

  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.public.id}"

}


/*
  Associate the public subnet with the above route table

  Dependencies: aws_subnet.public, aws_route_table.public
*/
resource "aws_route_table_association" "public" {

  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"

}

/* Module outputs */
output "vpc_id" {
  value = "${aws_vpc.environment.id}"
}

output "vpc_main_route_table_id" {
  value = "${aws_vpc.environment.main_route_table_id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.environment.cidr_block}"
}

#resource "aws_security_group" "example" {
#  name = "k8s-etcd-sg"
#  vpc_id  = "${aws_vpc.environment.id}"
#
#  ingress {
#    from_port = 0
#    to_port   = 0
#    protocol = "-1"
#    cidr_blocks = [ "0.0.0.0/0" ]
#  }

#  lifecycle {
#    create_before_destroy = true
#  }
#}
