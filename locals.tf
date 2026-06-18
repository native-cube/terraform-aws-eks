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

  karpenter_enabled              = var.karpenter.enabled
  karpenter_create_node_iam_role = local.karpenter_enabled && var.karpenter.create_node_iam_role
  karpenter_create_access_entry  = local.karpenter_enabled && var.karpenter.create_access_entry

  cluster_access_config = local.karpenter_create_access_entry ? {
    authentication_mode                         = coalesce(try(var.access_config.authentication_mode, null), "API_AND_CONFIG_MAP")
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
