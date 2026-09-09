resource "aws_eks_cluster" "this" {
  name                          = local.cluster_name
  role_arn                      = aws_iam_role.cluster.arn
  version                       = var.kubernetes_version
  bootstrap_self_managed_addons = local.cluster_bootstrap_self_managed_addons
  deletion_protection           = var.deletion_protection
  force_update_version          = var.force_update_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  dynamic "control_plane_scaling_config" {
    for_each = var.control_plane_scaling_config == null ? [] : [var.control_plane_scaling_config]

    content {
      tier = control_plane_scaling_config.value.tier
    }
  }

  dynamic "kube_api_server_config" {
    for_each = var.kube_api_server_config == null ? [] : [var.kube_api_server_config]

    content {
      event_ttl = kube_api_server_config.value.event_ttl

      dynamic "service_node_port_range" {
        for_each = kube_api_server_config.value.service_node_port_range == null ? [] : [kube_api_server_config.value.service_node_port_range]

        content {
          max_port = service_node_port_range.value.max_port
          min_port = service_node_port_range.value.min_port
        }
      }
    }
  }

  dynamic "kube_controller_manager_config" {
    for_each = var.kube_controller_manager_config == null ? [] : [var.kube_controller_manager_config]

    content {
      dynamic "horizontal_pod_autoscaler_controller_config" {
        for_each = kube_controller_manager_config.value.horizontal_pod_autoscaler_controller_config == null ? [] : [kube_controller_manager_config.value.horizontal_pod_autoscaler_controller_config]

        content {
          horizontal_pod_autoscaler_sync_period = horizontal_pod_autoscaler_controller_config.value.horizontal_pod_autoscaler_sync_period
        }
      }
    }
  }

  dynamic "kube_scheduler_config" {
    for_each = var.kube_scheduler_config == null ? [] : [var.kube_scheduler_config]

    content {
      dynamic "node_resources_fit" {
        for_each = kube_scheduler_config.value.node_resources_fit == null ? [] : [kube_scheduler_config.value.node_resources_fit]

        content {
          dynamic "scoring_strategy" {
            for_each = node_resources_fit.value.scoring_strategy == null ? [] : [node_resources_fit.value.scoring_strategy]

            content {
              type = scoring_strategy.value.type

              dynamic "resource" {
                for_each = scoring_strategy.value.resources

                content {
                  name   = resource.value.name
                  weight = resource.value.weight
                }
              }
            }
          }
        }
      }
    }
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.cluster_security_group_ids
  }

  dynamic "access_config" {
    for_each = local.cluster_access_config == null ? [] : [local.cluster_access_config]

    content {
      authentication_mode                         = access_config.value.authentication_mode
      bootstrap_cluster_creator_admin_permissions = access_config.value.bootstrap_cluster_creator_admin_permissions
    }
  }

  dynamic "compute_config" {
    for_each = local.auto_mode_configured ? [var.auto_mode] : []

    content {
      enabled       = local.auto_mode_enabled
      node_pools    = local.auto_mode_enabled ? compute_config.value.node_pools : null
      node_role_arn = local.auto_mode_builtin_node_pools ? local.auto_mode_node_iam_role_arn : null
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
    for_each = local.auto_mode_configured || var.ip_family != null || var.service_ipv4_cidr != null ? [1] : []

    content {
      ip_family         = var.ip_family
      service_ipv4_cidr = var.service_ipv4_cidr

      dynamic "elastic_load_balancing" {
        for_each = local.auto_mode_configured ? [local.auto_mode_enabled] : []

        content {
          enabled = elastic_load_balancing.value
        }
      }
    }
  }

  dynamic "storage_config" {
    for_each = local.auto_mode_configured ? [local.auto_mode_enabled] : []

    content {
      block_storage {
        enabled = storage_config.value
      }
    }
  }

  dynamic "upgrade_policy" {
    for_each = var.upgrade_policy_support_type == null ? [] : [var.upgrade_policy_support_type]

    content {
      support_type = upgrade_policy.value
    }
  }

  tags = local.common_tags

  lifecycle {
    # This setting is create-only. Ignoring later changes permits in-place Auto
    # Mode enablement for clusters originally created with bootstrap add-ons.
    ignore_changes = [bootstrap_self_managed_addons]

    precondition {
      condition = (
        try(var.kube_controller_manager_config.horizontal_pod_autoscaler_controller_config, null) == null ||
        try(var.control_plane_scaling_config.tier != "standard", false)
      )
      error_message = "kube_controller_manager_config.horizontal_pod_autoscaler_controller_config requires control_plane_scaling_config.tier to be tier-xl, tier-2xl, tier-4xl, or tier-8xl."
    }

    precondition {
      condition = (
        !local.api_authentication_required ||
        contains(["API", "API_AND_CONFIG_MAP"], try(local.cluster_access_config.authentication_mode, ""))
      )
      error_message = "Auto Mode, EKS access entries, Karpenter access entries, and EKS capabilities require access_config.authentication_mode to be API or API_AND_CONFIG_MAP."
    }

    precondition {
      condition = (
        local.auto_mode_enabled ||
        (
          length(var.auto_mode_node_classes) == 0 &&
          length(var.auto_mode_node_pools) == 0 &&
          length(var.auto_mode_storage_classes) == 0 &&
          length(var.auto_mode_load_balancer_services) == 0
        )
      )
      error_message = "Auto Mode Kubernetes manifests require auto_mode.enabled to be true."
    }

    precondition {
      condition = alltrue([
        for _, node_class in var.auto_mode_node_classes :
        try(node_class.spec.role, null) != null ||
        try(node_class.spec.instanceProfile, null) != null ||
        try(node_class.node_role_arn, null) != null ||
        local.auto_mode_node_iam_role_arn != null
      ])
      error_message = "Each Auto Mode NodeClass must specify a role, instanceProfile, or node_role_arn unless auto_mode supplies a node IAM role."
    }

    precondition {
      condition     = !var.endpoint_public_access || length(var.public_access_cidrs) > 0
      error_message = "public_access_cidrs must contain at least one CIDR when endpoint_public_access is true."
    }

    precondition {
      condition     = var.ip_family != "ipv6" || var.service_ipv4_cidr == null
      error_message = "service_ipv4_cidr cannot be set when ip_family is ipv6."
    }

    precondition {
      condition = (
        local.cluster_bootstrap_self_managed_addons ||
        length(var.node_groups) == 0 ||
        !contains(keys(var.addons), "vpc-cni") ||
        try(var.addons["vpc-cni"].before_compute, true)
      )
      error_message = "Clusters without bootstrapped self-managed add-ons must set addons[\"vpc-cni\"].before_compute to true when this module manages VPC CNI for managed node groups."
    }

    precondition {
      condition     = !local.auto_mode_enabled || !local.cluster_bootstrap_self_managed_addons
      error_message = "EKS Auto Mode requires bootstrap_self_managed_addons to be false."
    }

    precondition {
      condition     = length(distinct(local.managed_access_entry_principal_arns)) == length(local.managed_access_entry_principal_arns)
      error_message = "Each module- or service-managed EKS access entry must use a unique principal ARN. Reuse service-managed entries, or give NodeClasses sharing a custom role the same access_entry_key."
    }

    precondition {
      condition = alltrue([
        for _, configs in local.auto_mode_node_class_access_entry_groups :
        length(distinct([for config in configs : config.principal_arn])) == 1
      ])
      error_message = "NodeClasses sharing an access_entry_key must use the same node_role_arn."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.auto_mode_cluster_additional,
    aws_iam_role_policy_attachment.auto_mode_node,
    aws_iam_role_policy_attachment.auto_mode_node_additional,
    aws_iam_role_policy_attachment.cluster
  ]
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.this.name
  kubernetes_groups = each.value.kubernetes_groups
  principal_arn     = each.value.principal_arn
  tags              = local.common_tags
  type              = each.value.type
  user_name         = each.value.user_name
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.access_policy_associations

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    namespaces = each.value.access_scope.namespaces
    type       = each.value.access_scope.type
  }

  depends_on = [aws_eks_access_entry.this]
}

resource "aws_eks_access_entry" "auto_mode_node" {
  count = local.auto_mode_create_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.auto_mode_node_iam_role_arn
  tags          = local.common_tags
  type          = "EC2"
}

resource "aws_eks_access_policy_association" "auto_mode_node" {
  count = local.auto_mode_create_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = local.auto_mode_node_iam_role_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.auto_mode_node]
}

resource "aws_eks_access_entry" "auto_mode_node_class" {
  for_each = local.auto_mode_node_class_access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  tags          = local.common_tags
  type          = "EC2"

  lifecycle {
    precondition {
      condition     = each.value.principal_arn != null
      error_message = "Custom Auto Mode NodeClass access entries require auto_mode_node_classes[*].node_role_arn."
    }
  }
}

resource "aws_eks_access_policy_association" "auto_mode_node_class" {
  for_each = local.auto_mode_node_class_access_entries

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.auto_mode_node_class]
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = local.pod_identity_association_configs

  cluster_name         = aws_eks_cluster.this.name
  disable_session_tags = each.value.disable_session_tags
  namespace            = each.value.namespace
  role_arn             = local.pod_identity_iam_role_arns[each.key]
  service_account      = each.value.service_account
  tags                 = merge(local.common_tags, each.value.tags)
  target_role_arn      = each.value.target_role_arn

  depends_on = [
    aws_iam_role_policy.pod_identity,
    aws_iam_role_policy_attachment.pod_identity
  ]
}

resource "aws_ec2_tag" "karpenter_cluster_security_group" {
  count = local.karpenter_enabled && var.karpenter.tag_cluster_security_group ? 1 : 0

  resource_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = local.karpenter_discovery_tag_key
  value       = local.karpenter_discovery_tag_value
}

resource "aws_ec2_tag" "karpenter_subnets" {
  for_each = local.karpenter_enabled && var.karpenter.tag_subnets ? toset(local.karpenter_subnet_ids) : toset([])

  resource_id = each.value
  key         = local.karpenter_discovery_tag_key
  value       = local.karpenter_discovery_tag_value
}

resource "aws_eks_access_entry" "karpenter_node" {
  count = local.karpenter_create_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.karpenter_node_role_arn
  type          = "EC2_LINUX"
  tags          = local.common_tags

  lifecycle {
    precondition {
      condition     = contains(["API", "API_AND_CONFIG_MAP"], local.cluster_access_config.authentication_mode)
      error_message = "Karpenter access entries require access_config.authentication_mode to be API or API_AND_CONFIG_MAP."
    }
  }
}

resource "aws_eks_capability" "this" {
  for_each = local.eks_capability_configs

  capability_name           = each.value.capability_name
  cluster_name              = aws_eks_cluster.this.name
  delete_propagation_policy = each.value.delete_propagation_policy
  role_arn                  = local.eks_capability_iam_role_arns[each.key]
  tags                      = local.common_tags
  type                      = each.value.type

  dynamic "configuration" {
    for_each = each.value.type == "ARGOCD" && each.value.argocd != null ? [each.value.argocd] : []

    content {
      argo_cd {
        namespace = configuration.value.namespace

        aws_idc {
          idc_instance_arn = configuration.value.idc_instance_arn
          idc_region       = configuration.value.idc_region
        }

        dynamic "network_access" {
          for_each = length(configuration.value.network_access_vpce_ids) > 0 ? [configuration.value.network_access_vpce_ids] : []

          content {
            vpce_ids = network_access.value
          }
        }

        dynamic "rbac_role_mapping" {
          for_each = configuration.value.rbac_role_mappings

          content {
            role = rbac_role_mapping.value.role

            dynamic "identity" {
              for_each = rbac_role_mapping.value.identities

              content {
                id   = identity.value.id
                type = identity.value.type
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = contains(["API", "API_AND_CONFIG_MAP"], local.cluster_access_config.authentication_mode)
      error_message = "EKS capabilities require access_config.authentication_mode to be API or API_AND_CONFIG_MAP."
    }
  }

  depends_on = [
    aws_iam_role_policy.eks_capability,
    aws_iam_role_policy.eks_capability_preset,
    aws_iam_role_policy_attachment.eks_capability
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
    aws_eks_addon.before_compute,
    aws_iam_role_policy_attachment.node
  ]
}

resource "aws_eks_addon" "before_compute" {
  for_each = local.addons_before_compute

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
}

resource "aws_eks_addon" "this" {
  for_each = local.addons_after_compute

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
