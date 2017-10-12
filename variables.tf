data "aws_availability_zones" "zones" {}

variable "region" { description = "Region where VPC will be created" }

variable "availability_zones" {
  description = "Availability zones to configure"
  default     =  []
  type        = "list"
}

variable "name" {
  description = "Descriptive name for the VPC"
}

variable "cidr_block" { description = "CIDR block to allocate to the VPC" }

variable "cidr_block_bits" {
  description = "Variable subnet bits"
  default = "8"
}

variable "tags" {
  description = "A map of tags to all to all resources"
  default     = {}
}

variable "private_subnets" {
  default = []
}

variable "public_subnets" {
  default = []
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
  description = "Enable or disable DNS support and DNS hostnames"
  default = true
}

variable "create_vgw" {
  description = "Enabled or isable creation of a Virtual Private Gateway (VGW)"
  default = true
}

variable "customer_gateway_id" {
  description = "If create_vgw = true, the Customer Gateway Device (GGW) to use"
  default     = ""
}

variable "govcloud" {
  description = "Enable or disable GovCloud support"
  default     = false
}

variable "key_name" {
  description = "EC2 SSH key for NAT instance (only if govcloud = true)"
  default     = ""
}

/*
  The following variable is used to setup VPC peering.

  Simply list the VPC (by tag Name) to setup VPC Peering
*/
variable "peering_info" {
  description = "VPC tag Name to Peer with"
  type        = "list"
  default     = []
}

variable "enable_kubernetes" {
  description = "Enable or disable Kubernetes subnet creation"
  default     = false
}
