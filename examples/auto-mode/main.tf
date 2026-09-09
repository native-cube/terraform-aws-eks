terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "eks" {
  source = "../.."

  name               = var.name
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = var.subnet_ids

  # An empty object enables Auto Mode with the EKS built-in
  # general-purpose and system node pools.
  auto_mode = {}

  # This is a pure Auto Mode cluster: do not create managed node groups or
  # install the traditional EKS add-on resources.
  node_groups = {}
  addons      = {}

  # Version 2.0 keeps the module's public-and-private endpoint behavior.
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = var.public_access_cidrs

  tags = var.tags
}
