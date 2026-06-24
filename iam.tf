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

resource "aws_iam_role" "eks_capability" {
  for_each = local.eks_capability_create_iam_roles

  name               = each.value.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.capability_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_capability" {
  for_each = local.eks_capability_policy_attachments

  role       = aws_iam_role.eks_capability[each.value.capability_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "eks_capability" {
  for_each = {
    for key, capability in local.eks_capability_create_iam_roles : key => capability
    if capability.inline_policy_json != null
  }

  name   = substr("${each.value.iam_role_name}-policy", 0, 128)
  role   = aws_iam_role.eks_capability[each.key].id
  policy = each.value.inline_policy_json
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
