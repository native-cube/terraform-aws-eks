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

  control_plane_scaling_config = {
    tier = var.control_plane_scaling_tier
  }

  node_groups = {
    system = {
      instance_types = ["m7i.large"]
      min_size       = 2
      desired_size   = 2
      max_size       = 4
    }
  }

  tags = merge(
    var.tags,
    {
      Example = "provisioned-control-plane"
    }
  )
}
