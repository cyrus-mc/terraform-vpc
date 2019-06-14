/* VPC resource outputs */
output "vpc_id"         { value = aws_vpc.environment.id }
output "vpc_main_rt_id" { value = aws_vpc.environment.main_route_table_id }
output "vpc_cidr_block" { value = aws_vpc.environment.cidr_block }

/* Subnet resource outputs */
output "prvt_subnet_id"     { value = aws_subnet.private.*.id }
output "prvt_subnet_arn"    { value = aws_subnet.private.*.arn }
output "prvt_subnet_cidr"   { value = aws_subnet.private.*.cidr_block }
output "public_subnet_id"   { value = aws_subnet.public.*.id }
output "public_subnet_arn"  { value = aws_subnet.public.*.arn }
output "public_subnet_cidr" { value = aws_subnet.public.*.cidr_block }
