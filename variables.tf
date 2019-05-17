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
  /* if we supplied a non-empty value create the zone */
  create_zone = var.route53_zone == "" ? 0 : 1

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

variable "sg_cidr_blocks" {
  default     = []
  type        = list(string)
}

variable "tags" { default = {} }

variable "private_subnets" { default = [] }
variable "public_subnets"  { default = [] }

/*
  This allows us to add additional tags to the public subnet.

  Needed for Kubernetes, as an example, to tag with KubernetesCluster.
*/
variable "public_subnet_tags"  { default = {} }
variable "private_subnet_tags" { default = {} }

variable "enable_dns" { default = true }

variable "enable_public_ip" { default = false }

variable "create_vgw" { default = true }

variable "customer_gateway_id" {
  description = "If create_vgw = true, the Customer Gateway Device (GGW) to use"
  default     = ""
}

/* private route53 zone to create */
variable "route53_zone" {
  description = "The Route53 private zone to create and associate with this VPC"
  default     = ""
}
