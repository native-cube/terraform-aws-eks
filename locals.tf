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
}
