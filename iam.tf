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

resource "aws_iam_role_policy_attachment" "auto_mode_cluster_additional" {
  for_each = local.auto_mode_cluster_policy_arn_map

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

resource "aws_iam_role" "auto_mode_node" {
  count = local.auto_mode_create_node_iam_role ? 1 : 0

  name               = local.auto_mode_node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "auto_mode_node" {
  for_each = local.auto_mode_node_policy_arns

  role       = aws_iam_role.auto_mode_node[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "auto_mode_node_additional" {
  for_each = local.auto_mode_node_policy_arn_map

  role       = aws_iam_role.auto_mode_node[0].name
  policy_arn = each.value
}

resource "aws_iam_role" "pod_identity" {
  for_each = local.pod_identity_create_iam_roles

  name               = each.value.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json
  tags               = merge(local.common_tags, each.value.tags)
}

resource "aws_iam_role_policy_attachment" "pod_identity" {
  for_each = local.pod_identity_policy_attachments

  role       = aws_iam_role.pod_identity[each.value.association_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "pod_identity" {
  for_each = {
    for key, association in local.pod_identity_create_iam_roles : key => association
    if association.inline_policy_json != null
  }

  name   = substr("${each.value.iam_role_name}-policy", 0, 128)
  role   = aws_iam_role.pod_identity[each.key].id
  policy = each.value.inline_policy_json
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

resource "aws_iam_role_policy" "eks_capability_preset" {
  for_each = local.eks_capability_preset_policies

  name   = substr("${local.eks_capability_configs[each.value.capability_key].iam_role_name}-${each.value.preset_name}", 0, 128)
  role   = aws_iam_role.eks_capability[each.value.capability_key].id
  policy = jsonencode(local.eks_capability_iam_policy_preset_documents[each.value.preset_name])
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
