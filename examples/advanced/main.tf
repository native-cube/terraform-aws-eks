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

  name               = var.name
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = var.control_plane_subnet_ids

  cluster_security_group_ids = var.cluster_security_group_ids
  endpoint_private_access    = true
  endpoint_public_access     = var.endpoint_public_access
  public_access_cidrs        = var.public_access_cidrs

  access_config             = var.access_config
  deletion_protection       = var.deletion_protection
  cluster_encryption_config = var.cluster_encryption_config

  enabled_cluster_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_retention_days   = var.cloudwatch_log_retention_days
  cloudwatch_log_group_kms_key_id = var.cloudwatch_log_group_kms_key_id
  service_ipv4_cidr               = var.service_ipv4_cidr

  node_groups = {
    system = {
      capacity_type          = "ON_DEMAND"
      desired_size           = 2
      disk_size              = 50
      instance_types         = ["m7i.large"]
      labels                 = { workload = "system" }
      max_size               = 4
      min_size               = 2
      node_repair_config     = var.node_repair_config
      subnet_ids             = local.node_group_subnet_ids
      update_max_unavailable = 1
    }

    spot = {
      capacity_type = "SPOT"
      desired_size  = 1
      disk_size     = 50
      instance_types = [
        "m7i.large",
        "m7a.large",
        "m6i.large"
      ]
      labels = {
        capacity = "spot"
        workload = "application"
      }
      max_size               = 6
      min_size               = 0
      node_repair_config     = var.node_repair_config
      subnet_ids             = local.node_group_subnet_ids
      update_max_unavailable = 1
      taints = [
        {
          effect = "NO_SCHEDULE"
          key    = "capacity"
          value  = "spot"
        }
      ]
    }
  }

  addons = local.eks_addons

  tags = merge(
    var.tags,
    {
      Example = "advanced"
    }
  )
}

locals {
  node_group_subnet_ids = length(var.node_group_subnet_ids) > 0 ? var.node_group_subnet_ids : var.control_plane_subnet_ids

  addon_defaults = {
    configuration_values        = null
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
    service_account_role_arn    = null
    version                     = null
  }

  core_addons = {
    coredns    = local.addon_defaults
    kube-proxy = local.addon_defaults
    vpc-cni = merge(local.addon_defaults, {
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    })
  }

  platform_addons = {
    cert-manager              = local.addon_defaults
    eks-node-monitoring-agent = local.addon_defaults
    eks-pod-identity-agent    = local.addon_defaults
    fluent-bit                = local.addon_defaults
    kube-state-metrics        = local.addon_defaults
    metrics-server            = local.addon_defaults
    prometheus-node-exporter  = local.addon_defaults
    snapshot-controller       = local.addon_defaults
  }

  optional_iam_addons = merge(
    var.ebs_csi_driver_service_account_role_arn == null ? {} : {
      aws-ebs-csi-driver = merge(local.addon_defaults, {
        service_account_role_arn = var.ebs_csi_driver_service_account_role_arn
      })
    },
    var.efs_csi_driver_service_account_role_arn == null ? {} : {
      aws-efs-csi-driver = merge(local.addon_defaults, {
        service_account_role_arn = var.efs_csi_driver_service_account_role_arn
      })
    },
    var.cloudwatch_observability_service_account_role_arn == null ? {} : {
      amazon-cloudwatch-observability = merge(local.addon_defaults, {
        service_account_role_arn = var.cloudwatch_observability_service_account_role_arn
      })
    },
    var.external_dns_service_account_role_arn == null ? {} : {
      external-dns = merge(local.addon_defaults, {
        service_account_role_arn = var.external_dns_service_account_role_arn
      })
    }
  )

  eks_addons = merge(
    local.core_addons,
    local.platform_addons,
    local.optional_iam_addons
  )
}
