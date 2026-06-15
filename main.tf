resource "aws_eks_cluster" "this" {
  name                = local.cluster_name
  role_arn            = aws_iam_role.cluster.arn
  version             = var.kubernetes_version
  deletion_protection = var.deletion_protection

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.cluster_security_group_ids
  }

  dynamic "access_config" {
    for_each = var.access_config == null ? [] : [var.access_config]

    content {
      authentication_mode                         = access_config.value.authentication_mode
      bootstrap_cluster_creator_admin_permissions = access_config.value.bootstrap_cluster_creator_admin_permissions
    }
  }

  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config == null ? [] : [var.cluster_encryption_config]

    content {
      resources = encryption_config.value.resources

      provider {
        key_arn = encryption_config.value.provider_key_arn
      }
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = var.service_ipv4_cidr == null ? [] : [var.service_ipv4_cidr]

    content {
      service_ipv4_cidr = kubernetes_network_config.value
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster
  ]
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = substr("${var.name}-${each.key}", 0, 63)
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : var.subnet_ids

  ami_type       = each.value.ami_type
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size
  instance_types = each.value.instance_types
  labels         = each.value.labels
  version        = var.kubernetes_version

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = each.value.update_max_unavailable
  }

  dynamic "node_repair_config" {
    for_each = each.value.node_repair_config == null ? [] : [each.value.node_repair_config]

    content {
      enabled                                 = node_repair_config.value.enabled
      max_parallel_nodes_repaired_count       = node_repair_config.value.max_parallel_nodes_repaired_count
      max_parallel_nodes_repaired_percentage  = node_repair_config.value.max_parallel_nodes_repaired_percentage
      max_unhealthy_node_threshold_count      = node_repair_config.value.max_unhealthy_node_threshold_count
      max_unhealthy_node_threshold_percentage = node_repair_config.value.max_unhealthy_node_threshold_percentage

      dynamic "node_repair_config_overrides" {
        for_each = node_repair_config.value.overrides

        content {
          min_repair_wait_time_mins = node_repair_config_overrides.value.min_repair_wait_time_mins
          node_monitoring_condition = node_repair_config_overrides.value.node_monitoring_condition
          node_unhealthy_reason     = node_repair_config_overrides.value.node_unhealthy_reason
          repair_action             = node_repair_config_overrides.value.repair_action
        }
      }
    }
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    local.common_tags,
    {
      "eks-node-group" = each.key
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node
  ]
}

resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  configuration_values        = each.value.configuration_values
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update
  service_account_role_arn    = each.value.service_account_role_arn
  tags                        = local.common_tags

  dynamic "pod_identity_association" {
    for_each = each.value.pod_identity_associations

    content {
      role_arn        = pod_identity_association.value.role_arn
      service_account = pod_identity_association.value.service_account
    }
  }

  depends_on = [
    aws_eks_node_group.this
  ]
}
