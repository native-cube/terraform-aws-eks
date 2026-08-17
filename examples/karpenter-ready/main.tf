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

  endpoint_private_access = true
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs

  access_config = {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  node_groups = {
    system = {
      capacity_type          = "ON_DEMAND"
      desired_size           = 2
      disk_size              = 50
      instance_types         = var.system_node_instance_types
      labels                 = { workload = "system" }
      max_size               = 3
      min_size               = 1
      update_max_unavailable = 1
    }
  }

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  karpenter = {
    enabled                    = true
    create_access_entry        = true
    create_node_iam_role       = true
    subnet_ids                 = length(var.karpenter_subnet_ids) > 0 ? var.karpenter_subnet_ids : var.subnet_ids
    tag_cluster_security_group = true
    tag_subnets                = var.tag_karpenter_subnets
  }

  tags = merge(
    var.tags,
    {
      Example = "karpenter-ready"
    }
  )
}
