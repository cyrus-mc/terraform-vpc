################################################
#        Local Variable defintions             #
################################################
locals {
  /* Select the zones based on whether they are passed in, or query all zones */
  availability_zones = (length(var.availability_zones) == 0
                                                            ? data.aws_availability_zones.get_all.names
                                                            : var.availability_zones)
  /* Use passed in public subnets or generate */
  private_subnets = (length(var.private_subnets) == 0
                                                      ? null_resource.generated_private_subnets.*.triggers.cidr_block
                                                      : var.private_subnets)
  public_subnets  = (length(var.public_subnets) == 0
                                                     ? null_resource.generated_private_subnets.*.triggers.cidr_block
                                                     : var.public_subnets)

  /* default tags */
  tags = {
    Name       = format("%s", var.name)
    built-with = "terraform"
  }
}

variable "name" {}

variable "availability_zones" {
  default     = []
  type        = list(string)
}

variable "cidr_block"      {}
variable "cidr_block_bits" { default = "8" }

variable "secondary_cidr_block" {
  default = []
  type = list(string)
}

variable "sg_cidr_blocks" {
  default     = []
  type        = list(string)
}

variable "private_subnets" { default = [] }
variable "public_subnets"  { default = [] }

/*
  This allows us to add additional tags to the public subnet.

  Needed for Kubernetes, as an example, to tag with KubernetesCluster.
*/
variable "public_subnet_tags"  { default = {} }
variable "private_subnet_tags" { default = {} }

variable "enable_dns"       { default = true }
variable "enable_public_ip" { default = false }

variable "tags" { default = {} }
