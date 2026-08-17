terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.39.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "eks" {
  source = "../.."

  name         = var.name
  cluster_name = var.cluster_name
  subnet_ids   = var.subnet_ids

  tags = var.tags
}
