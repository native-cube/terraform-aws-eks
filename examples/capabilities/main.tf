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
  endpoint_public_access  = true
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
      instance_types         = var.node_instance_types
      labels                 = { workload = "system" }
      max_size               = 3
      min_size               = 1
      update_max_unavailable = 1
    }
  }

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  capabilities = {
    argocd = {
      type            = "ARGOCD"
      capability_name = "argocd"

      create_iam_role    = true
      iam_policy_arns    = var.argocd_capability_iam_policy_arns
      inline_policy_json = var.argocd_capability_inline_policy_json

      argocd = {
        namespace               = "argocd"
        idc_instance_arn        = var.identity_center_instance_arn
        idc_region              = var.identity_center_region
        network_access_vpce_ids = var.argocd_private_vpce_ids
        rbac_role_mappings      = local.argocd_rbac_role_mappings
      }
    }

    ack = {
      type            = "ACK"
      capability_name = "ack"

      create_iam_role    = true
      iam_policy_arns    = var.ack_capability_iam_policy_arns
      inline_policy_json = var.ack_capability_inline_policy_json
    }

    kro = {
      type            = "KRO"
      capability_name = "kro"

      create_iam_role    = true
      iam_policy_arns    = var.kro_capability_iam_policy_arns
      inline_policy_json = var.kro_capability_inline_policy_json
    }
  }

  tags = merge(
    var.tags,
    {
      Example = "capabilities"
    }
  )
}

locals {
  argocd_rbac_role_mappings = var.argocd_admin_group_id == null ? [] : [
    {
      role = "ADMIN"
      identities = [
        {
          id   = var.argocd_admin_group_id
          type = "SSO_GROUP"
        }
      ]
    }
  ]
}
