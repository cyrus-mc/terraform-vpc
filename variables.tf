# data source used to query all availability zones
data "aws_availability_zones" "all" {}

variable "region" {
  description = "Region where VPC will be created"
}

variable "cidr_block" {
  description = "VPC CIDR block"
}

variable "cidr_block_bits" {}

variable "cidr_block_start" {}
variable "cidr_block_end" {}

variable "environment" {}

variable "customer_gateway_id" {}

variable "key_name" {}

variable "aws_govcloud" {
  description = "Deployment into AWS GovCloud region"
  default     = false
}
