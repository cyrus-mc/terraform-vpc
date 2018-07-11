module "test1" {
  source = "../"

  availability_zones = [ "us-west-2a" ]

  cidr_block      = "10.0.0.0/16"
  public_subnets  = [ "10.0.0.0/16" ]
  private_subnets = [ "10.1.0.0/16" ]

  name   = "test1"
  region = "us-west-2"

  public_subnet_tags {
    tag1 = "value1"
  }

  private_subnet_tags {
    tag1 = "value1"
  }
}

module "test2" {
  source = "../"

  availability_zones = [ "us-west-2a", "us-west-2b" ]

  cidr_block      = "10.0.0.0/16"
  public_subnets  = [ "10.0.0.0/16" ]
  private_subnets = [ "10.1.0.0/16" ]

  name   = "test1"
  region = "us-west-2"

  public_subnet_tags {
    tag1 = "value1"
  }

  private_subnet_tags {
    tag1 = "value1"
  }
}

