module "test1" {
  source = "../"

  availability_zones = [ "us-west-2a" ]

  cidr_block      = "10.36.8.0/22"
  private_subnets = [ "10.36.10.0/24", "10.36.11.0/24" ]
  public_subnets  = [ "10.36.8.0/24", "10.36.9.0/24" ]

  name = "test1"

  public_subnet_tags = {
    tag1 = "value1"
  }

  private_subnet_tags = {
    tag1 = "value1"
  }
}

module "test2" {
  source = "../"

  availability_zones = [ "us-west-2a", "us-west-2b" ]

  cidr_block      = "10.36.8.0/22"
  cidr_block_bits = "2"

  name = "test1"

  network_acl_rules = [
    {
      type = "ingress"
      protocol = "tcp"
      action = "allow"
      from_port = 443
      to_port   = 443
    },
    {
      type = "egress"
      protocol = "tcp"
      action = "deny"
      from_port = 80
      to_port = 8080
    },
    {
      type = "ingress"
      protocol = "tcp"
      action = "allow"
      from_port = 8443
      to_port   = 8443
     }
  ]

  public_subnet_tags = {
    tag1 = "value1"
  }

  private_subnet_tags = {
    tag1 = "value1"
  }
}

