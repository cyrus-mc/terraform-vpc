module "test1" {
  source = "../"

  availability_zones = [ "us-west-2a" ]

  cidr_block      = "10.36.8.0/22"
  private_subnets = [ "10.36.10.0/24", "10.36.11.0/24" ]
  public_subnets  = [ "10.36.8.0/24", "10.36.9.0/24" ]

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

  cidr_block      = "10.36.8.0/22"
  cidr_block_bits = "2"

  name   = "test1"
  region = "us-west-2"

  public_subnet_tags {
    tag1 = "value1"
  }

  private_subnet_tags {
    tag1 = "value1"
  }
}

