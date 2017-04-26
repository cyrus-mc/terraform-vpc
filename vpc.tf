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

  /* create subnet at the end of the cidr block */
  cidr_block = "${cidrsubnet(aws_vpc.environment.cidr_block, 8, format("%d", 254 - count.index))}"
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

output "private_subnet_id" {
  value = [ "${aws_subnet.private.*.id}" ]
}

output "private_subnet_cidr" {
  value = [ "${aws_subnet.private.*.cidr_block}" ]
}

output "public_subnet_id" {
  value = [ "${aws_subnet.public.*.id}" ]
}

output "public_subnet_cidr" {
  value = [ "${aws_subnet.public.*.cidr_block}" ]
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
