# data source used to query all availability zones
data "aws_availability_zones" "all" {}

variable "region" {
  description = "Region where VPC will be created"
}

variable "cidr_block" {
  description = "VPC CIDR block"

}

variable "environment" {}

variable "customer_gateway_id" {}
