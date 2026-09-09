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

  auto_mode_configured           = var.auto_mode != null
  auto_mode_enabled              = try(var.auto_mode.enabled, false)
  auto_mode_builtin_node_pools   = local.auto_mode_enabled && length(try(var.auto_mode.node_pools, toset([]))) > 0
  auto_mode_create_node_iam_role = local.auto_mode_configured && try(var.auto_mode.create_node_iam_role, true)
  auto_mode_global_node_role     = local.auto_mode_create_node_iam_role || try(var.auto_mode.node_iam_role_arn, null) != null
  auto_mode_create_access_entry = local.auto_mode_enabled && !local.auto_mode_builtin_node_pools && (
    try(var.auto_mode.create_access_entry, null) != null ?
    var.auto_mode.create_access_entry :
    local.auto_mode_global_node_role
  )
  auto_mode_node_role_name    = coalesce(try(var.auto_mode.node_iam_role_name, null), substr("${var.name}-auto-node-role", 0, 64))
  auto_mode_node_iam_role_arn = local.auto_mode_create_node_iam_role ? try(aws_iam_role.auto_mode_node[0].arn, null) : try(var.auto_mode.node_iam_role_arn, null)
  auto_mode_external_node_role_name = try(var.auto_mode.node_iam_role_arn, null) == null ? try(var.auto_mode.node_iam_role_name, null) : coalesce(
    try(var.auto_mode.node_iam_role_name, null),
    reverse(split("/", var.auto_mode.node_iam_role_arn))[0]
  )
  auto_mode_node_iam_role_name = local.auto_mode_global_node_role ? (
    local.auto_mode_create_node_iam_role ? try(aws_iam_role.auto_mode_node[0].name, local.auto_mode_node_role_name) : local.auto_mode_external_node_role_name
  ) : null
  cluster_bootstrap_self_managed_addons = coalesce(var.bootstrap_self_managed_addons, local.auto_mode_configured ? false : true)

  cluster_assume_role_actions = concat(
    ["sts:AssumeRole"],
    local.auto_mode_configured ? ["sts:TagSession"] : []
  )

  cluster_policy_arns = setunion(
    toset([
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
    ]),
    local.auto_mode_configured ? toset([
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSBlockStoragePolicyV2",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSComputePolicy",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSNetworkingPolicy"
    ]) : toset([]),
    local.auto_mode_configured ? try(var.auto_mode.cluster_iam_policy_arns, toset([])) : toset([])
  )
  auto_mode_cluster_policy_arn_map = local.auto_mode_configured ? try(var.auto_mode.cluster_iam_policy_arn_map, {}) : {}

  node_policy_arns = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  addons_before_compute = {
    for name, addon in var.addons : name => addon
    if addon.before_compute
  }

  addons_after_compute = {
    for name, addon in var.addons : name => addon
    if !addon.before_compute
  }

  auto_mode_node_policy_arns = local.auto_mode_create_node_iam_role ? setunion(toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  ]), try(var.auto_mode.node_iam_policy_arns, toset([]))) : toset([])
  auto_mode_node_policy_arn_map = local.auto_mode_create_node_iam_role ? try(var.auto_mode.node_iam_policy_arn_map, {}) : {}

  pod_identity_association_configs = {
    for key, association in var.pod_identity_associations : key => {
      create_iam_role        = try(association.create_iam_role, true)
      disable_session_tags   = try(association.disable_session_tags, null)
      iam_policy_arn_map     = try(association.iam_policy_arn_map, {})
      iam_policy_arns        = try(association.iam_policy_arns, toset([]))
      iam_role_arn           = try(association.iam_role_arn, null)
      iam_role_name          = coalesce(try(association.iam_role_name, null), substr("${local.cluster_name}-${key}-pod-identity", 0, 64))
      iam_role_name_override = try(association.iam_role_name, null)
      inline_policy_json     = try(association.inline_policy_json, null)
      namespace              = association.namespace
      service_account        = association.service_account
      tags                   = try(association.tags, {})
      target_role_arn        = try(association.target_role_arn, null)
    }
  }

  pod_identity_create_iam_roles = {
    for key, association in local.pod_identity_association_configs : key => association
    if association.create_iam_role
  }

  pod_identity_policy_attachments = length(local.pod_identity_create_iam_roles) == 0 ? {} : merge([
    for association_key, association in local.pod_identity_create_iam_roles : merge(
      {
        for policy_arn in association.iam_policy_arns : "${association_key}:${policy_arn}" => {
          association_key = association_key
          policy_arn      = policy_arn
        }
      },
      {
        for policy_key, policy_arn in association.iam_policy_arn_map : "${association_key}:key:${policy_key}" => {
          association_key = association_key
          policy_arn      = policy_arn
        }
      }
    )
  ]...)

  pod_identity_iam_role_arns = {
    for key, association in local.pod_identity_association_configs :
    key => association.create_iam_role ? try(aws_iam_role.pod_identity[key].arn, null) : association.iam_role_arn
  }

  pod_identity_external_role_names = {
    for key, association in local.pod_identity_association_configs :
    key => association.iam_role_arn == null ? association.iam_role_name : coalesce(association.iam_role_name_override, reverse(split("/", association.iam_role_arn))[0])
  }

  pod_identity_iam_role_names = {
    for key, association in local.pod_identity_association_configs :
    key => association.create_iam_role ? try(aws_iam_role.pod_identity[key].name, association.iam_role_name) : local.pod_identity_external_role_names[key]
  }

  access_policy_associations = length(var.access_entries) == 0 ? {} : merge([
    for entry_key, entry in var.access_entries : {
      for association_key, association in entry.policy_associations : "${entry_key}:${association_key}" => {
        access_scope  = association.access_scope
        entry_key     = entry_key
        policy_arn    = association.policy_arn
        principal_arn = entry.principal_arn
      }
    }
  ]...)

  eks_capability_configs = {
    for key, capability in var.capabilities : key => {
      capability_name           = coalesce(try(capability.capability_name, null), key)
      create_iam_role           = try(capability.create_iam_role, true)
      delete_propagation_policy = try(capability.delete_propagation_policy, "RETAIN")
      iam_policy_arn_map        = try(capability.iam_policy_arn_map, {})
      iam_policy_arns           = try(capability.iam_policy_arns, toset([]))
      iam_policy_presets        = try(capability.iam_policy_presets, toset([]))
      iam_role_arn              = try(capability.iam_role_arn, null)
      iam_role_name             = coalesce(try(capability.iam_role_name, null), substr("${upper(capability.type)}CapabilityRole-${local.cluster_name}-${key}", 0, 64))
      iam_role_name_override    = try(capability.iam_role_name, null)
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

  eks_capability_iam_policy_preset_documents = {
    cloudcontrol_read_only = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "cloudcontrol:GetResource",
            "cloudcontrol:ListResourceRequests",
            "cloudcontrol:ListResources"
          ]
          Resource = "*"
        }
      ]
    }
    eks_read_only = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "eks:DescribeAccessEntry",
            "eks:DescribeCluster",
            "eks:DescribePodIdentityAssociation",
            "eks:ListAccessEntries",
            "eks:ListClusters",
            "eks:ListPodIdentityAssociations"
          ]
          Resource = "*"
        }
      ]
    }
    resource_tagging = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "tag:GetResources",
            "tag:GetTagKeys",
            "tag:GetTagValues",
            "tag:TagResources",
            "tag:UntagResources"
          ]
          Resource = "*"
        }
      ]
    }
    secrets_read_only = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:ListSecrets"
          ]
          Resource = "*"
        }
      ]
    }
  }

  eks_capabilities_enabled = length(local.eks_capability_configs) > 0
  eks_capability_create_iam_roles = {
    for key, capability in local.eks_capability_configs : key => capability
    if capability.create_iam_role
  }
  eks_capability_policy_attachments = length(local.eks_capability_create_iam_roles) == 0 ? {} : merge([
    for capability_key, capability in local.eks_capability_create_iam_roles : merge(
      {
        for policy_arn in capability.iam_policy_arns : "${capability_key}:${policy_arn}" => {
          capability_key = capability_key
          policy_arn     = policy_arn
        }
      },
      {
        for policy_key, policy_arn in capability.iam_policy_arn_map : "${capability_key}:key:${policy_key}" => {
          capability_key = capability_key
          policy_arn     = policy_arn
        }
      }
    )
  ]...)
  eks_capability_preset_policies = length(local.eks_capability_create_iam_roles) == 0 ? {} : merge([
    for capability_key, capability in local.eks_capability_create_iam_roles : {
      for preset_name in capability.iam_policy_presets : "${capability_key}:${preset_name}" => {
        capability_key = capability_key
        preset_name    = preset_name
      }
    }
  ]...)
  eks_capability_iam_role_arns = {
    for key, capability in local.eks_capability_configs :
    key => capability.create_iam_role ? try(aws_iam_role.eks_capability[key].arn, null) : capability.iam_role_arn
  }
  eks_capability_external_role_names = {
    for key, capability in local.eks_capability_configs :
    key => capability.iam_role_arn == null ? capability.iam_role_name : coalesce(capability.iam_role_name_override, reverse(split("/", capability.iam_role_arn))[0])
  }
  eks_capability_iam_role_names = {
    for key, capability in local.eks_capability_configs :
    key => capability.create_iam_role ? try(aws_iam_role.eks_capability[key].name, capability.iam_role_name) : local.eks_capability_external_role_names[key]
  }

  auto_mode_node_class_specs = {
    for name, node_class in var.auto_mode_node_classes :
    name => merge(
      (
        try(node_class.spec.role, null) == null &&
        try(node_class.spec.instanceProfile, null) == null &&
        (
          try(node_class.node_role_arn, null) != null ||
          local.auto_mode_node_iam_role_name != null
        )
        ) ? {
        role = try(node_class.node_role_arn, null) == null ? local.auto_mode_node_iam_role_name : reverse(split("/", node_class.node_role_arn))[0]
      } : {},
      node_class.spec
    )
  }

  auto_mode_node_class_access_entry_configs = {
    for name, node_class in var.auto_mode_node_classes : name => {
      access_entry_key = coalesce(try(node_class.access_entry_key, null), name)
      create_access_entry = (
        try(node_class.create_access_entry, null) != null ?
        node_class.create_access_entry :
        try(node_class.node_role_arn, null) != null
      )
      principal_arn = try(node_class.node_role_arn, null)
    }
  }
  auto_mode_node_class_access_entry_groups = {
    for name, config in local.auto_mode_node_class_access_entry_configs :
    config.access_entry_key => merge(config, { node_class_name = name })...
    if config.create_access_entry
  }
  auto_mode_node_class_access_entries = {
    for access_entry_key, configs in local.auto_mode_node_class_access_entry_groups :
    access_entry_key => {
      node_class_names = [for config in configs : config.node_class_name]
      principal_arn    = configs[0].principal_arn
    }
  }

  auto_mode_node_class_manifests = {
    for name, node_class in var.auto_mode_node_classes : name => yamlencode({
      apiVersion = "eks.amazonaws.com/v1"
      kind       = "NodeClass"
      metadata = merge(
        { name = name },
        length(node_class.annotations) > 0 ? { annotations = node_class.annotations } : {},
        length(node_class.labels) > 0 ? { labels = node_class.labels } : {}
      )
      spec = local.auto_mode_node_class_specs[name]
    })
  }

  auto_mode_node_pool_manifests = {
    for name, node_pool in var.auto_mode_node_pools : name => yamlencode({
      apiVersion = "karpenter.sh/v1"
      kind       = "NodePool"
      metadata = merge(
        { name = name },
        length(node_pool.annotations) > 0 ? { annotations = node_pool.annotations } : {},
        length(node_pool.labels) > 0 ? { labels = node_pool.labels } : {}
      )
      spec = node_pool.spec
    })
  }

  auto_mode_storage_class_manifests = {
    for name, storage_class in var.auto_mode_storage_classes : name => yamlencode(merge(
      {
        apiVersion = "storage.k8s.io/v1"
        kind       = "StorageClass"
        metadata = merge(
          { name = name },
          length(storage_class.annotations) > 0 ? { annotations = storage_class.annotations } : {},
          length(storage_class.labels) > 0 ? { labels = storage_class.labels } : {}
        )
        provisioner = "ebs.csi.eks.amazonaws.com"
        parameters = merge(
          {
            encrypted = "true"
            type      = "gp3"
          },
          storage_class.parameters
        )
        reclaimPolicy        = storage_class.reclaim_policy
        volumeBindingMode    = storage_class.volume_binding_mode
        allowVolumeExpansion = storage_class.allow_volume_expansion
      },
      length(storage_class.allowed_topologies) > 0 ? { allowedTopologies = storage_class.allowed_topologies } : {},
      length(storage_class.mount_options) > 0 ? { mountOptions = storage_class.mount_options } : {}
    ))
  }

  auto_mode_load_balancer_service_manifests = {
    for name, service in var.auto_mode_load_balancer_services : name => yamlencode({
      apiVersion = "v1"
      kind       = "Service"
      metadata = merge(
        {
          name      = name
          namespace = service.namespace
        },
        length(service.annotations) > 0 ? { annotations = service.annotations } : {},
        length(service.labels) > 0 ? { labels = service.labels } : {}
      )
      spec = merge(
        {
          type              = "LoadBalancer"
          loadBalancerClass = service.load_balancer_class
          ports             = service.ports
          selector          = service.selector
        },
        service.external_traffic_policy == null ? {} : { externalTrafficPolicy = service.external_traffic_policy },
        length(service.ip_families) > 0 ? { ipFamilies = service.ip_families } : {},
        service.ip_family_policy == null ? {} : { ipFamilyPolicy = service.ip_family_policy },
        length(service.load_balancer_source_ranges) > 0 ? { loadBalancerSourceRanges = service.load_balancer_source_ranges } : {},
        service.session_affinity == null ? {} : { sessionAffinity = service.session_affinity }
      )
    })
  }

  auto_mode_kubernetes_manifests = merge(
    {
      for name, manifest in local.auto_mode_node_class_manifests :
      "nodeclass/${name}" => manifest
    },
    {
      for name, manifest in local.auto_mode_node_pool_manifests :
      "nodepool/${name}" => manifest
    },
    {
      for name, manifest in local.auto_mode_storage_class_manifests :
      "storageclass/${name}" => manifest
    },
    {
      for name, manifest in local.auto_mode_load_balancer_service_manifests :
      "service/${name}" => manifest
    }
  )

  karpenter_enabled              = var.karpenter.enabled
  karpenter_create_node_iam_role = local.karpenter_enabled && var.karpenter.create_node_iam_role
  karpenter_create_access_entry  = local.karpenter_enabled && var.karpenter.create_access_entry

  api_authentication_required = (
    local.auto_mode_configured ||
    local.karpenter_create_access_entry ||
    local.eks_capabilities_enabled ||
    length(var.access_entries) > 0 ||
    length(local.auto_mode_node_class_access_entries) > 0
  )

  cluster_access_config = local.api_authentication_required ? {
    authentication_mode                         = coalesce(try(var.access_config.authentication_mode, null), "API")
    bootstrap_cluster_creator_admin_permissions = try(var.access_config.bootstrap_cluster_creator_admin_permissions, null)
  } : var.access_config

  managed_node_group_access_entry_enabled = (
    length(var.node_groups) > 0 &&
    contains(["API", "API_AND_CONFIG_MAP"], try(local.cluster_access_config.authentication_mode, ""))
  )
  managed_access_entry_principal_arns = compact(concat(
    [for _, entry in var.access_entries : entry.principal_arn],
    [for _, entry in local.auto_mode_node_class_access_entries : entry.principal_arn],
    distinct(values(local.eks_capability_iam_role_arns)),
    local.managed_node_group_access_entry_enabled ? [aws_iam_role.node.arn] : [],
    local.karpenter_create_access_entry ? [local.karpenter_node_role_arn] : [],
    (local.auto_mode_builtin_node_pools || local.auto_mode_create_access_entry) ? [local.auto_mode_node_iam_role_arn] : []
  ))

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
