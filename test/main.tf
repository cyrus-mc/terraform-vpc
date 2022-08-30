module "test1" {
  source = "../"

  availability_zones = [ "us-west-2a" ]

  cidr_block = "10.36.8.0/22"
  secondary_cidr_blocks = { public = "10.0.0.0/22" }

  private_subnets = {
    primary = [ "10.36.10.0/24", "10.36.11.0/24" ]
  }

  public_subnets = {
    primary = [ "10.36.8.0/24", "10.36.9.0/24" ]
  }

  name = "test1"

  public_subnet_tags = {
    all = {
      tag1 = "value1"
    }
  }

  private_subnet_tags = {
    all = {
      tag1 = "value1"
    }
  }
}

module "test2" {
  source = "../"

  availability_zones = [ "us-west-2a", "us-west-2b" ]

  cidr_block = "10.36.0.0/20"

  private_subnets = {
    primary = [ "10.36.10.0/24", "10.36.11.0/24" ]
    eks     = [ "10.36.12.0/24", "10.36.13.0/24" ]
  }

  public_subnets = {
    primary = [ "10.36.8.0/24", "10.36.9.0/24" ]
  }

  name = "test1"

  network_acls = {
    private = [
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
  }

  features = {
    nat_gateway = false
    internet_gateway = false
  }

  public_subnet_tags = {
    primary = {
      tag1 = "value1"
    }
  }

  private_subnet_tags = {
    primary = {
      tag1 = "value1"
    }
  }
}

