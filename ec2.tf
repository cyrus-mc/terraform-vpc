resource "aws_instance" "nat_instance" {
  
  /* only required if deploying into AWS GovCloud region */
  count = "${var.aws_govcloud}"

  /* Amazon Linux AMI */
  ami           = "ami-6ae2660b"
  instance_type = "t2.large"

  /* define build details (user_data, key, instance profile) */
  key_name      = "${var.key_name}"

  /* define network details about the instance (subnet, private IP) */
  subnet_id                   = "${aws_subnet.public.id}"
  private_ip                  = "${cidrhost(aws_subnet.public.cidr_block, 10)}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [ "${aws_security_group.nat-instance.id}" ]

  /* disable source and destination check */
  source_dest_check           = false

  tags {
    builtWith  = "terraform"
    Name       = "nat-instance"
    visibility = "public"
  }

}
