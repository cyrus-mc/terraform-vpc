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

variable "tags" {
  description = "A map of tags to all to all resources"
  default     = {}
}

/*
  This allows us to add additional tags to the public subnet.

  Needed for Kubernetes, as an example, to tag with KubernetesCluster.
*/
variable "public_subnet_tags" {
  description = "Additional tags for public subnets"
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnets"
  default     = {}
}

variable "enable_dns" {
  default = true
}

variable "create_vgw" {
  description = "Create a Virtual Private Gateway"
  default = true
}

variable "environment" {}

variable "customer_gateway_id" {}

variable "key_name" {
  description = "Only needed for GovCloud, key to use for NAT instance"
  default     = ""
}

variable "peering_info" {
  type = "list"
}
variable "aws_govcloud" {
  description = "Deployment into AWS GovCloud region"
  default     = false
}
