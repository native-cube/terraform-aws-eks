terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "eks" {
  source = "../.."

  name               = var.name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = var.subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.public_access_cidrs

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      desired_size   = 2
      max_size       = 3
    }
  }

  tags = var.tags
}
