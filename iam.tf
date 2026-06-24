resource "aws_iam_role" "cluster" {
  name               = local.cluster_role_name
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = local.cluster_policy_arns

  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_iam_role" "node" {
  name               = local.node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.node_policy_arns

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_role" "argocd_capability" {
  count = local.argocd_create_iam_role ? 1 : 0

  name               = local.argocd_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.capability_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "argocd_capability" {
  for_each = local.argocd_iam_policy_arns

  role       = aws_iam_role.argocd_capability[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "argocd_capability" {
  count = local.argocd_create_iam_role && var.argocd.inline_policy_json != null ? 1 : 0

  name   = substr("${local.argocd_iam_role_name}-policy", 0, 128)
  role   = aws_iam_role.argocd_capability[0].id
  policy = var.argocd.inline_policy_json
}

resource "aws_iam_role" "karpenter_node" {
  count = local.karpenter_create_node_iam_role ? 1 : 0

  name               = local.karpenter_node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = local.karpenter_create_node_iam_role ? local.karpenter_node_policy_arns : toset([])

  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = each.value
}
