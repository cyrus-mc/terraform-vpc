provider "aws" {
  profile = "dev"
  region  = "us-west-2"
}

resource "null_resource" "stub" {}
