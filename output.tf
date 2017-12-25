/* VPC resource outputs */
output "vpc_id" {
  value = "${aws_vpc.environment.id}"
}

output "vpc_main_rt_id" {
  value = "${aws_vpc.environment.main_route_table_id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.environment.cidr_block}"
}

/* Subnet resource outputs */

output "prvt_subnet_id" {
  value = [ "${aws_subnet.private.*.id}" ]
}

output "prvt_subnet_cidr" {
  value = [ "${aws_subnet.private.*.cidr_block}" ]
}

output "public_subnet_id" {
  value = [ "${aws_subnet.public.*.id}" ]
}

output "public_subnet_cidr" {
  value = [ "${aws_subnet.public.*.cidr_block}" ]
}

output "nat_instance_id" {
  value = "${aws_instance.nat_instance.*.id}"
}

/* Kubernetes subnet details */
output "kubernetes_subnet_id" {
  value = [ "${aws_subnet.kubernetes.*.id}" ]
}

output "kubernetes_subnet_cidr_block" {
  value = [ "${aws_subnet.kubernetes.*.cidr_block}" ]
}
