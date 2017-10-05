/*
  Query information of VPC to peer with
*/
data "aws_vpc" "peering" {

  count = "${length(var.peering_info)}"

  filter {
    name = "tag:Name"
    values = [ "${element(var.peering_info, count.index)}" ]
  }
}


/*
  Query the main route table associated with the above VPC(s)
*/
data "aws_route_table" "peering" {

  count = "${length(var.peering_info)}"

  vpc_id = "${element(data.aws_vpc.peering.*.id, count.index)}"

  filter {
    name = "association.main"
    values = [ "true" ]
  }
}
