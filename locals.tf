locals {
  cluster_name = coalesce(var.cluster_name, var.name)

  common_tags = merge(
    var.tags,
    {
      "terraform-module" = "eks"
      "eks-cluster"      = local.cluster_name
    }
  )

  cluster_role_name = substr("${var.name}-cluster-role", 0, 64)
  node_role_name    = substr("${var.name}-node-role", 0, 64)

  cluster_policy_arns = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  ])

  node_policy_arns = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  eks_capability_configs = {
    for key, capability in var.capabilities : key => {
      capability_name           = coalesce(try(capability.capability_name, null), key)
      create_iam_role           = try(capability.create_iam_role, true)
      delete_propagation_policy = try(capability.delete_propagation_policy, "RETAIN")
      iam_policy_arns           = try(capability.iam_policy_arns, toset([]))
      iam_role_arn              = try(capability.iam_role_arn, null)
      iam_role_name             = coalesce(try(capability.iam_role_name, null), substr("${upper(capability.type)}CapabilityRole-${local.cluster_name}-${key}", 0, 64))
      inline_policy_json        = try(capability.inline_policy_json, null)
      type                      = upper(capability.type)
      argocd = try(capability.argocd, null) == null ? null : {
        idc_instance_arn        = try(capability.argocd.idc_instance_arn, null)
        idc_region              = try(capability.argocd.idc_region, null)
        namespace               = try(capability.argocd.namespace, null)
        network_access_vpce_ids = try(capability.argocd.network_access_vpce_ids, toset([]))
        rbac_role_mappings      = try(capability.argocd.rbac_role_mappings, [])
      }
    }
  }

  eks_capabilities_enabled = length(local.eks_capability_configs) > 0
  eks_capability_create_iam_roles = {
    for key, capability in local.eks_capability_configs : key => capability
    if capability.create_iam_role
  }
  eks_capability_policy_attachments = length(local.eks_capability_create_iam_roles) == 0 ? {} : merge([
    for capability_key, capability in local.eks_capability_create_iam_roles : {
      for policy_arn in capability.iam_policy_arns : "${capability_key}:${policy_arn}" => {
        capability_key = capability_key
        policy_arn     = policy_arn
      }
    }
  ]...)
  eks_capability_iam_role_arns = {
    for key, capability in local.eks_capability_configs :
    key => capability.create_iam_role ? try(aws_iam_role.eks_capability[key].arn, null) : capability.iam_role_arn
  }
  eks_capability_external_role_names = {
    for key, capability in local.eks_capability_configs :
    key => capability.iam_role_arn == null ? capability.iam_role_name : coalesce(capability.iam_role_name, reverse(split("/", capability.iam_role_arn))[0])
  }
  eks_capability_iam_role_names = {
    for key, capability in local.eks_capability_configs :
    key => capability.create_iam_role ? try(aws_iam_role.eks_capability[key].name, capability.iam_role_name) : local.eks_capability_external_role_names[key]
  }

  karpenter_enabled              = var.karpenter.enabled
  karpenter_create_node_iam_role = local.karpenter_enabled && var.karpenter.create_node_iam_role
  karpenter_create_access_entry  = local.karpenter_enabled && var.karpenter.create_access_entry

  cluster_access_config = local.karpenter_create_access_entry || local.eks_capabilities_enabled ? {
    authentication_mode                         = coalesce(try(var.access_config.authentication_mode, null), "API")
    bootstrap_cluster_creator_admin_permissions = try(var.access_config.bootstrap_cluster_creator_admin_permissions, null)
  } : var.access_config

  karpenter_discovery_tag_key   = "karpenter.sh/discovery"
  karpenter_discovery_tag_value = local.cluster_name
  karpenter_subnet_ids          = length(var.karpenter.subnet_ids) > 0 ? var.karpenter.subnet_ids : var.subnet_ids
  karpenter_node_role_name      = coalesce(var.karpenter.node_iam_role_name, substr("KarpenterNodeRole-${local.cluster_name}", 0, 64))
  karpenter_node_role_arn       = local.karpenter_create_node_iam_role ? try(aws_iam_role.karpenter_node[0].arn, null) : var.karpenter.node_iam_role_arn
  karpenter_external_role_name  = var.karpenter.node_iam_role_arn == null ? var.karpenter.node_iam_role_name : coalesce(var.karpenter.node_iam_role_name, reverse(split("/", var.karpenter.node_iam_role_arn))[0])
  karpenter_node_role_name_out  = local.karpenter_create_node_iam_role ? try(aws_iam_role.karpenter_node[0].name, local.karpenter_node_role_name) : local.karpenter_external_role_name

  karpenter_node_policy_arns = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
}
