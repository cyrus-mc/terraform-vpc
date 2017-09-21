# data source used to query all availability zones
data "aws_availability_zones" "all" {}

variable "region" {
  description = "Region where VPC will be created"
}

variable "cidr_block" {
  description = "VPC CIDR block"
}

variable "cidr_block_bits" {
  default = "8"
}

variable "cidr_block_start" {
  default = "254"
}

variable "cidr_block_end" {
  default = "255"
}

variable "environment" {}

variable "customer_gateway_id" {}

variable "key_name" {
  description = "Only needed for GovCloud, key to use for NAT instance"
  default     = ""
}

variable "aws_govcloud" {
  description = "Deployment into AWS GovCloud region"
  default     = false
}
