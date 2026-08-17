resource "aws_eks_cluster" "this" {
  name                = local.cluster_name
  role_arn            = aws_iam_role.cluster.arn
  version             = var.kubernetes_version
  deletion_protection = var.deletion_protection

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

  lifecycle {
    precondition {
      condition = (
        try(var.kube_controller_manager_config.horizontal_pod_autoscaler_controller_config, null) == null ||
        try(var.control_plane_scaling_config.tier != "standard", false)
      )
      error_message = "kube_controller_manager_config.horizontal_pod_autoscaler_controller_config requires control_plane_scaling_config.tier to be tier-xl, tier-2xl, tier-4xl, or tier-8xl."
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster
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
