resource "aws_instance" "nat_instance" {

  /* only required if deploying into AWS GovCloud region */
  count = "${var.govcloud}"

  /* Amazon Linux AMI */
  ami           = "ami-6ae2660b"
  instance_type = "t2.large"

  /* define build details (user_data, key, instance profile) */
  key_name      = "${var.key_name}"

  /* define network details about the instance (subnet, private IP) */
  subnet_id      = "${element(aws_subnet.public.*.id, 1)}"

  private_ip                  = "${cidrhost(element(aws_subnet.public.*.cidr_block, 1), 10)}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [ "${aws_security_group.nat-instance.id}" ]

  /* disable source and destination check */
  source_dest_check           = false

  tags {
    builtWith  = "terraform"
    Name       = "nat-instance:${var.name}"
    visibility = "public"
  }

}

/*
  Provision DNS servers to be used as forwarders
*/
module "dns" {

  source = "git::ssh://git@bitbucket.org/datdevops/tf-aws_dns.git?ref=1.0.2"

  /* set the region */
  region = "${var.region}"

  /* list of subnets to deploy in (must all exist in same VPC) */
  subnet_id = [ "${aws_subnet.private.*.id}" ]

  /* key pair to provision EC2 instance with */
  key_name = "${var.key_name}"

  /* enable or disable provisioning of the DNS servers for this VPC */
  enable = "${var.deploy_dns}"

}
