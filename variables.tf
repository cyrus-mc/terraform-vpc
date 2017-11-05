################################################
#        Local Variable defintions             #
################################################
locals {
  /*
    Select the zones based on whether they are passed in, or query all zones

    NOTE: work around as conditional logic does not work with lists or maps
  */
  availability_zones = [ "${split(",",
      length(var.availability_zones) == 0
          ? join(",", data.aws_availability_zones.get_all.names)
          : join(",", var.availability_zones))}" ]

  /*
    Use passed in public subnets or generate
  */
  private_subnets = [ "${split(",",
      length(var.private_subnets) == 0
          ? join(",", null_resource.generated_private_subnets.*.triggers.cidr_block)
          : join(",", var.private_subnets))}" ]

  public_subnets = [ "${split(",",
      length(var.public_subnets) == 0
          ? join(",", null_resource.generated_public_subnets.*.triggers.cidr_block)
          : join(",", var.public_subnets))}" ]

  domain_name = "${var.region == "us-east-1" ? "ec2.internal" : format("%s.compute.internal", var.region)}"

}

/* query all the availability zones */
data "aws_availability_zones" "zones" {}

variable "region" { description = "Region where VPC will be created" }

variable "name" {
  description = "Descriptive name for the VPC"
}


variable "availability_zones" {
  description = "List of availability zones to provision subnets in"
  default     =  []
  type        = "list"
}

variable "cidr_block" { description = "CIDR block to allocate to the VPC" }

variable "cidr_block_bits" {
  description = "Variable subnet bits"
  default = "8"
}

variable "sg_cidr_blocks" {
  description = "Network cidr blocks to allow inbound on default security group"
  default = []
  type    = "list"
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

variable "enable_public_ip" {
  description = "Enable or disable mapping of public IP in public subnets"
  default = false
}

variable "create_vgw" {
  description = "Enabled or isable creation of a Virtual Private Gateway (VGW)"
  default = true
}

variable "customer_gateway_id" {
  description = "If create_vgw = true, the Customer Gateway Device (GGW) to use"
  default     = ""
}

variable "enable_kubernetes" {
  description = "Enable or disable Kubernetes subnet creation"
  default     = false
}

variable "deploy_dns" {
  description = "Flag to control whether to deploy DNS forwarders"
  default     = false
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

/* following settings deal explicitly with GovCloud */
variable "govcloud" {
  description = "Enable or disable GovCloud support"
  default     = false
}

variable "key_name" {
  description = "EC2 SSH key for NAT instance (only if govcloud = true)"
  default     = ""
}
