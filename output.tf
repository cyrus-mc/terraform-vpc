/* VPC resource outputs */
output "vpc_id"         { value = aws_vpc.environment.id }
output "vpc_main_rt_id" { value = aws_vpc.environment.main_route_table_id }
output "vpc_cidr_block" { value = aws_vpc.environment.cidr_block }

/* subnet resource outputs */
output "prvt_subnet_id" {
  value = [ for obj in aws_subnet.private: obj.id ]
}
output "prvt_subnet_arn" {
  value = [ for obj in aws_subnet.private: obj.arn ]
}
output "prvt_subnet_cidr" {
  value = [ for obj in aws_subnet.private: obj.cidr_block  ]
}
output "public_subnet_id" {
  value = [ for obj in aws_subnet.public: obj.id ]
}
output "public_subnet_arn" {
  value = [ for obj in aws_subnet.public: obj.arn ]
}
output "public_subnet_cidr" {
  value = [ for obj in aws_subnet.public: obj.cidr_block ]
}

output "prvt_subnet_id_by_group" {
  value = { for key, value in local.private_subnets:
              value.group => aws_subnet.private[key].id... }
}

output "prvt_subnet_arn_by_group" {
  value = { for key, value in local.private_subnets:
              value.group => aws_subnet.private[key].arn... }
}

output "prvt_subnet_cidr_by_group" {
  value = { for key, value in local.private_subnets:
              value.group => aws_subnet.private[key].cidr_block... }
}

output "public_subnet_id_by_group" {
  value = { for key, value in local.public_subnets:
              value.group => aws_subnet.public[key].id... }
}

output "public_subnet_arn_by_group" {
  value = { for key, value in local.public_subnets:
              value.group => aws_subnet.public[key].arn... }
}

output "public_subnet_cidr_by_group" {
  value = { for key, value in local.public_subnets:
              value.group => aws_subnet.public[key].cidr_block... }
}

/* route table outputs */
output "prvt_route_table_id"   {
  value = [ for obj in aws_route_table.private: obj.id ]
}
output "public_route_table_id" { value = aws_route_table.public.*.id }
