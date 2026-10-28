terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Mumbai region (closest to Chennai)
provider "aws" {
  region = "ap-south-1"
}
