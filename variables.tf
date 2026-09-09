variable "name" {
  description = "Name prefix for module-created resources. Used as the EKS cluster name when cluster_name is null."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,99}$", var.name))
    error_message = "The name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "cluster_name" {
  description = "Optional EKS cluster name. When null, name is used as the cluster name."
  type        = string
  default     = null

  validation {
    condition     = var.cluster_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,99}$", var.cluster_name))
    error_message = "The cluster_name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster and managed node groups. Leave null to use the current AWS default."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS control plane and default node groups. Use at least two subnets in different Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least two subnet IDs."
  }
}

variable "cluster_security_group_ids" {
  description = "Additional security group IDs to associate with the EKS control plane."
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Whether the Kubernetes API server endpoint is reachable from within the VPC."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server endpoint is reachable from the public internet."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can access the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "access_config" {
  description = "Optional EKS access configuration for cluster authentication mode and creator admin permissions."
  type = object({
    authentication_mode                         = optional(string)
    bootstrap_cluster_creator_admin_permissions = optional(bool)
  })
  default = null

  validation {
    condition = (
      var.access_config == null ||
      var.access_config.authentication_mode == null ||
      contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.access_config.authentication_mode)
    )
    error_message = "access_config.authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection for the EKS cluster. Leave null to use the AWS/provider default."
  type        = bool
  default     = null
}

variable "bootstrap_self_managed_addons" {
  description = "Whether EKS bootstraps self-managed networking add-ons at cluster creation. Leave null to derive true for standard clusters and false while Auto Mode is configured. This setting is create-only."
  type        = bool
  default     = null
}

variable "force_update_version" {
  description = "Whether to force a Kubernetes version update when EKS cannot drain pods."
  type        = bool
  default     = null
}

variable "control_plane_scaling_config" {
  description = "Optional EKS Provisioned Control Plane scaling configuration. Leave null to use the standard control plane scaling tier."
  type = object({
    tier = string
  })
  default = null

  validation {
    condition = (
      var.control_plane_scaling_config == null ||
      contains(["standard", "tier-xl", "tier-2xl", "tier-4xl", "tier-8xl"], var.control_plane_scaling_config.tier)
    )
    error_message = "control_plane_scaling_config.tier must be standard, tier-xl, tier-2xl, tier-4xl, or tier-8xl."
  }
}

variable "kube_api_server_config" {
  description = "Optional Kubernetes API server configuration for event retention and the NodePort service range."
  type = object({
    event_ttl = optional(string)
    service_node_port_range = optional(object({
      max_port = optional(number)
      min_port = optional(number)
    }))
  })
  default = null

  validation {
    condition = try(
      var.kube_api_server_config.event_ttl == null ? true :
      can(regex("^(1h|[1-5][0-9]m|60m)$", var.kube_api_server_config.event_ttl)),
      true
    )
    error_message = "kube_api_server_config.event_ttl must be a single-unit duration from 10m to 60m; 1h is also accepted."
  }

  validation {
    condition = try(
      var.kube_api_server_config.service_node_port_range == null ? true : alltrue([
        var.kube_api_server_config.service_node_port_range.min_port == null ? true : (
          floor(var.kube_api_server_config.service_node_port_range.min_port) == var.kube_api_server_config.service_node_port_range.min_port &&
          var.kube_api_server_config.service_node_port_range.min_port >= 10260 &&
          var.kube_api_server_config.service_node_port_range.min_port <= 32767
        ),
        var.kube_api_server_config.service_node_port_range.max_port == null ? true : (
          floor(var.kube_api_server_config.service_node_port_range.max_port) == var.kube_api_server_config.service_node_port_range.max_port &&
          var.kube_api_server_config.service_node_port_range.max_port >= 10260 &&
          var.kube_api_server_config.service_node_port_range.max_port <= 32767
        ),
        coalesce(var.kube_api_server_config.service_node_port_range.min_port, 30000) <= coalesce(var.kube_api_server_config.service_node_port_range.max_port, 32767)
      ]),
      true
    )
    error_message = "kube_api_server_config.service_node_port_range ports must be integers from 10260 to 32767, and max_port must be greater than or equal to min_port."
  }
}

variable "kube_controller_manager_config" {
  description = "Optional Kubernetes controller manager configuration. HPA controller customization requires a Provisioned Control Plane tier."
  type = object({
    horizontal_pod_autoscaler_controller_config = optional(object({
      horizontal_pod_autoscaler_sync_period = optional(string)
    }))
  })
  default = null

  validation {
    condition = try(
      var.kube_controller_manager_config.horizontal_pod_autoscaler_controller_config == null ? true :
      var.kube_controller_manager_config.horizontal_pod_autoscaler_controller_config.horizontal_pod_autoscaler_sync_period == null ? true :
      can(regex("^1[0-5]s$", var.kube_controller_manager_config.horizontal_pod_autoscaler_controller_config.horizontal_pod_autoscaler_sync_period)),
      true
    )
    error_message = "kube_controller_manager_config.horizontal_pod_autoscaler_controller_config.horizontal_pod_autoscaler_sync_period must be a single-unit duration from 10s to 15s."
  }
}

variable "kube_scheduler_config" {
  description = "Optional Kubernetes scheduler configuration for the NodeResourcesFit scoring strategy."
  type = object({
    node_resources_fit = optional(object({
      scoring_strategy = optional(object({
        resources = optional(list(object({
          name   = optional(string)
          weight = optional(number)
        })), [])
        type = optional(string)
      }))
    }))
  })
  default = null

  validation {
    condition = try(
      var.kube_scheduler_config.node_resources_fit == null ? true :
      var.kube_scheduler_config.node_resources_fit.scoring_strategy == null ? true :
      var.kube_scheduler_config.node_resources_fit.scoring_strategy.type == null ? true :
      contains(["LeastAllocated", "MostAllocated"], var.kube_scheduler_config.node_resources_fit.scoring_strategy.type),
      true
    )
    error_message = "kube_scheduler_config.node_resources_fit.scoring_strategy.type must be LeastAllocated or MostAllocated."
  }

  validation {
    condition = try(
      var.kube_scheduler_config.node_resources_fit == null ? true :
      var.kube_scheduler_config.node_resources_fit.scoring_strategy == null ? true :
      alltrue([
        for resource in var.kube_scheduler_config.node_resources_fit.scoring_strategy.resources :
        (resource.name == null ? true : trimspace(resource.name) != "") &&
        (resource.weight == null ? true : (
          floor(resource.weight) == resource.weight &&
          resource.weight >= 1 &&
          resource.weight <= 100
        ))
      ]),
      true
    )
    error_message = "kube_scheduler_config scoring resources must have non-empty names when set and integer weights from 1 to 100."
  }
}

variable "cluster_encryption_config" {
  description = "Optional EKS encryption configuration for Kubernetes secrets using an existing KMS key."
  type = object({
    provider_key_arn = string
    resources        = optional(list(string), ["secrets"])
  })
  default = null

  validation {
    condition = (
      var.cluster_encryption_config == null ||
      alltrue([
        for resource in var.cluster_encryption_config.resources :
        resource == "secrets"
      ])
    )
    error_message = "cluster_encryption_config.resources currently supports only secrets."
  }
}

variable "enabled_cluster_log_types" {
  description = "EKS control plane log types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]

  validation {
    condition = alltrue([
      for log_type in var.enabled_cluster_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Cluster log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "Retention in days for the EKS control plane CloudWatch log group."
  type        = number
  default     = 30

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
      1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "CloudWatch log retention must be a valid AWS retention value."
  }
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "Optional KMS key ID or ARN for encrypting the EKS control plane CloudWatch log group."
  type        = string
  default     = null
}

variable "auto_mode" {
  description = "Optional EKS Auto Mode configuration. Null leaves Auto Mode unmanaged for backward compatibility; an empty object enables Auto Mode with its default node pools. Set enabled to false to explicitly disable previously managed Auto Mode capabilities."
  type = object({
    cluster_iam_policy_arn_map = optional(map(string), {})
    cluster_iam_policy_arns    = optional(set(string), [])
    create_access_entry        = optional(bool)
    create_node_iam_role       = optional(bool, true)
    enabled                    = optional(bool, true)
    node_iam_policy_arn_map    = optional(map(string), {})
    node_iam_policy_arns       = optional(set(string), [])
    node_iam_role_arn          = optional(string)
    node_iam_role_name         = optional(string)
    node_pools                 = optional(set(string), ["general-purpose", "system"])
  })
  default = null

  validation {
    condition = var.auto_mode == null ? true : (
      !var.auto_mode.enabled ||
      length(var.auto_mode.node_pools) == 0 ||
      var.auto_mode.create_node_iam_role ||
      var.auto_mode.node_iam_role_arn != null
    )
    error_message = "When Auto Mode built-in node pools are enabled and create_node_iam_role is false, auto_mode.node_iam_role_arn must be set."
  }

  validation {
    condition = var.auto_mode == null ? true : (
      var.auto_mode.create_access_entry != true || (
        var.auto_mode.enabled &&
        length(var.auto_mode.node_pools) == 0 &&
        (var.auto_mode.create_node_iam_role || var.auto_mode.node_iam_role_arn != null)
      )
    )
    error_message = "auto_mode.create_access_entry=true requires enabled Auto Mode without built-in node pools and a module-created or external node IAM role."
  }

  validation {
    condition = var.auto_mode == null ? true : (
      alltrue([
        for node_pool in var.auto_mode.node_pools :
        contains(["general-purpose", "system"], node_pool)
      ])
    )
    error_message = "auto_mode.node_pools supports only general-purpose and system."
  }

  validation {
    condition = var.auto_mode == null ? true : (
      var.auto_mode.node_iam_role_name == null ||
      can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.auto_mode.node_iam_role_name))
    )
    error_message = "auto_mode.node_iam_role_name must be 1-64 characters and contain only IAM role name characters."
  }

  validation {
    condition = var.auto_mode == null ? true : alltrue([
      for key in concat(keys(var.auto_mode.cluster_iam_policy_arn_map), keys(var.auto_mode.node_iam_policy_arn_map)) :
      can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", key))
    ])
    error_message = "auto_mode IAM policy map keys must be stable identifiers containing only letters, numbers, periods, underscores, and hyphens."
  }
}

variable "ip_family" {
  description = "Optional Kubernetes service IP family. Valid values are ipv4 or ipv6."
  type        = string
  default     = null

  validation {
    condition     = var.ip_family == null || contains(["ipv4", "ipv6"], var.ip_family)
    error_message = "ip_family must be ipv4 or ipv6."
  }
}

variable "service_ipv4_cidr" {
  description = "Optional Kubernetes service IPv4 CIDR. Set only when you need a non-default service CIDR."
  type        = string
  default     = null
}

variable "upgrade_policy_support_type" {
  description = "Optional Kubernetes version support policy. Valid values are STANDARD and EXTENDED."
  type        = string
  default     = null

  validation {
    condition     = var.upgrade_policy_support_type == null || contains(["STANDARD", "EXTENDED"], var.upgrade_policy_support_type)
    error_message = "upgrade_policy_support_type must be STANDARD or EXTENDED."
  }
}

variable "node_groups" {
  description = "Managed node groups to create."
  type = map(object({
    ami_type               = optional(string)
    capacity_type          = optional(string, "ON_DEMAND")
    desired_size           = optional(number, 2)
    disk_size              = optional(number, 20)
    instance_types         = optional(list(string), ["t3.medium"])
    labels                 = optional(map(string), {})
    max_size               = optional(number, 3)
    min_size               = optional(number, 1)
    subnet_ids             = optional(list(string), [])
    update_max_unavailable = optional(number, 1)
    node_repair_config = optional(object({
      enabled                                 = optional(bool)
      max_parallel_nodes_repaired_count       = optional(number)
      max_parallel_nodes_repaired_percentage  = optional(number)
      max_unhealthy_node_threshold_count      = optional(number)
      max_unhealthy_node_threshold_percentage = optional(number)
      overrides = optional(list(object({
        min_repair_wait_time_mins = number
        node_monitoring_condition = string
        node_unhealthy_reason     = string
        repair_action             = string
      })), [])
    }))
    taints = optional(list(object({
      effect = string
      key    = string
      value  = optional(string, "")
    })), [])
  }))
  default = {
    default = {}
  }

  validation {
    condition = alltrue([
      for _, group in var.node_groups :
      contains(["ON_DEMAND", "SPOT"], group.capacity_type)
    ])
    error_message = "Node group capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition = alltrue([
      for _, group in var.node_groups :
      group.min_size <= group.desired_size && group.desired_size <= group.max_size
    ])
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size."
  }

  validation {
    condition = alltrue([
      for _, group in var.node_groups :
      group.update_max_unavailable >= 1
    ])
    error_message = "Each node group update_max_unavailable must be at least 1."
  }

  validation {
    condition = alltrue(flatten([
      for _, group in var.node_groups : [
        for taint in group.taints :
        contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], taint.effect)
      ]
    ]))
    error_message = "Taint effect must be NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE."
  }
}

variable "addons" {
  description = "EKS add-ons to install. Set before_compute for add-ons such as vpc-cni that managed nodes need during bootstrap."
  type = map(object({
    before_compute       = optional(bool, false)
    configuration_values = optional(string)
    pod_identity_associations = optional(list(object({
      role_arn        = string
      service_account = string
    })), [])
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    version                     = optional(string)
  }))
  default = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
}

variable "access_entries" {
  description = "Additional EKS access entries and optional access policy associations to create."
  type = map(object({
    kubernetes_groups = optional(set(string), [])
    policy_associations = optional(map(object({
      access_scope = object({
        namespaces = optional(set(string), [])
        type       = string
      })
      policy_arn = string
    })), {})
    principal_arn = string
    type          = optional(string, "STANDARD")
    user_name     = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, entry in var.access_entries :
      contains(["STANDARD", "EC2", "EC2_LINUX", "EC2_WINDOWS", "FARGATE_LINUX", "HYBRID_LINUX"], entry.type)
    ])
    error_message = "access_entries[*].type must be STANDARD, EC2, EC2_LINUX, EC2_WINDOWS, FARGATE_LINUX, or HYBRID_LINUX."
  }

  validation {
    condition = alltrue(flatten([
      for _, entry in var.access_entries : [
        for _, association in entry.policy_associations :
        contains(["cluster", "namespace"], association.access_scope.type)
      ]
    ]))
    error_message = "access_entries[*].policy_associations[*].access_scope.type must be cluster or namespace."
  }

  validation {
    condition = alltrue(flatten([
      for _, entry in var.access_entries : [
        for _, association in entry.policy_associations :
        association.access_scope.type == "namespace" || length(association.access_scope.namespaces) == 0
      ]
    ]))
    error_message = "access_entries[*].policy_associations[*].access_scope.namespaces must be empty when access_scope.type is cluster."
  }

  validation {
    condition = alltrue(flatten([
      for _, entry in var.access_entries : [
        for _, association in entry.policy_associations :
        association.access_scope.type != "namespace" || length(association.access_scope.namespaces) > 0
      ]
    ]))
    error_message = "access_entries[*].policy_associations[*].access_scope.namespaces must contain at least one namespace when access_scope.type is namespace."
  }

  validation {
    condition = alltrue([
      for _, entry in var.access_entries :
      entry.type == "STANDARD" ||
      length(entry.policy_associations) == 0 ||
      (
        entry.type == "EC2" &&
        alltrue([
          for _, association in entry.policy_associations :
          can(regex(":eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy$", association.policy_arn)) &&
          association.access_scope.type == "cluster"
        ])
      )
    ])
    error_message = "Only STANDARD access entries may define arbitrary policy associations. EC2 entries may associate only AmazonEKSAutoNodePolicy at cluster scope."
  }

  validation {
    condition = alltrue([
      for _, entry in var.access_entries :
      entry.type == "STANDARD" || (length(entry.kubernetes_groups) == 0 && entry.user_name == null)
    ])
    error_message = "Only STANDARD access entries may define kubernetes_groups or user_name."
  }

  validation {
    condition     = length(distinct([for _, entry in var.access_entries : entry.principal_arn])) == length(var.access_entries)
    error_message = "access_entries must not contain duplicate principal ARNs."
  }
}

variable "auto_mode_node_classes" {
  description = "Custom EKS Auto Mode NodeClass manifests to render as YAML, keyed by Kubernetes metadata.name. The module does not apply these manifests."
  type = map(object({
    access_entry_key    = optional(string)
    annotations         = optional(map(string), {})
    create_access_entry = optional(bool)
    labels              = optional(map(string), {})
    node_role_arn       = optional(string)
    spec                = any
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.auto_mode_node_classes :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name)) && length(name) <= 63 && name != "default"
    ])
    error_message = "auto_mode_node_classes keys must be DNS label names up to 63 characters and must not be default."
  }

  validation {
    condition = alltrue([
      for _, node_class in var.auto_mode_node_classes :
      !(try(node_class.spec.role, null) != null && try(node_class.spec.instanceProfile, null) != null)
    ])
    error_message = "auto_mode_node_classes[*].spec must not set both role and instanceProfile."
  }

  validation {
    condition = alltrue([
      for _, node_class in var.auto_mode_node_classes :
      node_class.create_access_entry == false || (
        try(node_class.spec.role, null) == null &&
        try(node_class.spec.instanceProfile, null) == null
      ) || node_class.node_role_arn != null
    ])
    error_message = "A NodeClass with a custom spec.role or spec.instanceProfile must set node_role_arn unless create_access_entry=false."
  }

  validation {
    condition = alltrue([
      for _, node_class in var.auto_mode_node_classes :
      node_class.create_access_entry != true || node_class.node_role_arn != null
    ])
    error_message = "auto_mode_node_classes[*].create_access_entry=true requires node_role_arn."
  }

  validation {
    condition = alltrue([
      for name, node_class in var.auto_mode_node_classes :
      node_class.access_entry_key == null || (
        can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", node_class.access_entry_key)) &&
        node_class.node_role_arn != null &&
        node_class.create_access_entry != false
      )
    ])
    error_message = "auto_mode_node_classes[*].access_entry_key must be a stable identifier and requires an enabled access entry with node_role_arn."
  }

  validation {
    condition = alltrue([
      for _, node_class in var.auto_mode_node_classes :
      node_class.node_role_arn == null ||
      try(node_class.spec.role, null) == null ||
      reverse(split("/", node_class.node_role_arn))[0] == node_class.spec.role
    ])
    error_message = "auto_mode_node_classes[*].spec.role must match the role name in node_role_arn when both are set."
  }
}

variable "auto_mode_node_pools" {
  description = "Custom EKS Auto Mode NodePool manifests to render as YAML, keyed by Kubernetes metadata.name. The module does not apply these manifests."
  type = map(object({
    annotations = optional(map(string), {})
    labels      = optional(map(string), {})
    spec        = any
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.auto_mode_node_pools :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name)) && length(name) <= 63
    ])
    error_message = "auto_mode_node_pools keys must be DNS label names up to 63 characters."
  }
}

variable "auto_mode_storage_classes" {
  description = "EKS Auto Mode EBS StorageClass manifests to render as YAML, keyed by Kubernetes metadata.name."
  type = map(object({
    allow_volume_expansion = optional(bool, true)
    allowed_topologies     = optional(list(any), [])
    annotations            = optional(map(string), {})
    labels                 = optional(map(string), {})
    mount_options          = optional(list(string), [])
    parameters             = optional(map(string), {})
    reclaim_policy         = optional(string, "Delete")
    volume_binding_mode    = optional(string, "WaitForFirstConsumer")
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.auto_mode_storage_classes :
      can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", name)) && length(name) <= 253
    ])
    error_message = "auto_mode_storage_classes keys must be valid Kubernetes storage class names up to 253 characters."
  }

  validation {
    condition = alltrue([
      for _, storage_class in var.auto_mode_storage_classes :
      contains(["Delete", "Retain"], storage_class.reclaim_policy)
    ])
    error_message = "auto_mode_storage_classes[*].reclaim_policy must be Delete or Retain."
  }

  validation {
    condition = alltrue([
      for _, storage_class in var.auto_mode_storage_classes :
      contains(["Immediate", "WaitForFirstConsumer"], storage_class.volume_binding_mode)
    ])
    error_message = "auto_mode_storage_classes[*].volume_binding_mode must be Immediate or WaitForFirstConsumer."
  }
}

variable "auto_mode_load_balancer_services" {
  description = "EKS Auto Mode Network Load Balancer Service manifests to render as YAML, keyed by Kubernetes metadata.name."
  type = map(object({
    annotations                 = optional(map(string), {})
    external_traffic_policy     = optional(string)
    ip_families                 = optional(list(string), [])
    ip_family_policy            = optional(string)
    labels                      = optional(map(string), {})
    load_balancer_class         = optional(string, "eks.amazonaws.com/nlb")
    load_balancer_source_ranges = optional(list(string), [])
    namespace                   = optional(string, "default")
    ports                       = list(any)
    selector                    = map(string)
    session_affinity            = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.auto_mode_load_balancer_services :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", name)) && length(name) <= 63
    ])
    error_message = "auto_mode_load_balancer_services keys must be DNS label names up to 63 characters."
  }

  validation {
    condition = alltrue([
      for _, service in var.auto_mode_load_balancer_services :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", service.namespace)) && length(service.namespace) <= 63
    ])
    error_message = "auto_mode_load_balancer_services[*].namespace must be a DNS label up to 63 characters."
  }
}

variable "pod_identity_associations" {
  description = "EKS Pod Identity associations to create for Kubernetes service accounts. The module can create the IAM role per association, or use an externally managed role ARN."
  type = map(object({
    create_iam_role      = optional(bool, true)
    disable_session_tags = optional(bool)
    iam_policy_arn_map   = optional(map(string), {})
    iam_policy_arns      = optional(set(string), [])
    iam_role_arn         = optional(string)
    iam_role_name        = optional(string)
    inline_policy_json   = optional(string)
    namespace            = string
    service_account      = string
    tags                 = optional(map(string), {})
    target_role_arn      = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, association in var.pod_identity_associations :
      association.create_iam_role || association.iam_role_arn != null
    ])
    error_message = "When pod_identity_associations[*].create_iam_role is false, pod_identity_associations[*].iam_role_arn must be set."
  }

  validation {
    condition = alltrue([
      for _, association in var.pod_identity_associations :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", association.namespace)) && length(association.namespace) <= 63
    ])
    error_message = "pod_identity_associations[*].namespace must be a DNS label up to 63 characters."
  }

  validation {
    condition = alltrue([
      for _, association in var.pod_identity_associations :
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", association.service_account)) && length(association.service_account) <= 63
    ])
    error_message = "pod_identity_associations[*].service_account must be a DNS label up to 63 characters."
  }

  validation {
    condition = alltrue([
      for _, association in var.pod_identity_associations :
      association.iam_role_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", association.iam_role_name))
    ])
    error_message = "pod_identity_associations[*].iam_role_name must be 1-64 characters and contain only IAM role name characters."
  }

  validation {
    condition = alltrue(flatten([
      for _, association in var.pod_identity_associations : [
        for key in keys(association.iam_policy_arn_map) :
        can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", key))
      ]
    ]))
    error_message = "pod_identity_associations[*].iam_policy_arn_map keys must be stable identifiers containing only letters, numbers, periods, underscores, and hyphens."
  }
}

variable "capabilities" {
  description = "Amazon EKS managed capabilities to create, keyed by a stable local name. Supported types are ARGOCD, ACK, and KRO. The module can create a capability IAM role per entry, or use an externally managed role ARN."
  type = map(object({
    capability_name           = optional(string)
    create_iam_role           = optional(bool, true)
    delete_propagation_policy = optional(string, "RETAIN")
    iam_policy_arn_map        = optional(map(string), {})
    iam_policy_arns           = optional(set(string), [])
    iam_policy_presets        = optional(set(string), [])
    iam_role_arn              = optional(string)
    iam_role_name             = optional(string)
    inline_policy_json        = optional(string)
    type                      = string
    argocd = optional(object({
      idc_instance_arn        = optional(string)
      idc_region              = optional(string)
      namespace               = optional(string)
      network_access_vpce_ids = optional(set(string), [])
      rbac_role_mappings = optional(list(object({
        role = string
        identities = list(object({
          id   = string
          type = string
        }))
      })), [])
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      contains(["ACK", "ARGOCD", "KRO"], upper(capability.type))
    ])
    error_message = "capabilities entries must use type ACK, ARGOCD, or KRO."
  }

  validation {
    condition     = length(distinct([for _, capability in var.capabilities : upper(capability.type)])) == length(var.capabilities)
    error_message = "Only one capability of each type may be configured per EKS cluster."
  }

  validation {
    condition = alltrue(flatten([
      for _, capability in var.capabilities : [
        for preset in capability.iam_policy_presets :
        contains(["cloudcontrol_read_only", "eks_read_only", "resource_tagging", "secrets_read_only"], preset)
      ]
    ]))
    error_message = "capabilities[*].iam_policy_presets supports cloudcontrol_read_only, eks_read_only, resource_tagging, and secrets_read_only."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      capability.create_iam_role || capability.iam_role_arn != null
    ])
    error_message = "When capabilities[*].create_iam_role is false, capabilities[*].iam_role_arn must be set."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      capability.capability_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,99}$", capability.capability_name))
    ])
    error_message = "capabilities[*].capability_name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      capability.delete_propagation_policy == "RETAIN"
    ])
    error_message = "capabilities[*].delete_propagation_policy currently supports only RETAIN."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      capability.iam_role_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", capability.iam_role_name))
    ])
    error_message = "capabilities[*].iam_role_name must be 1-64 characters and contain only IAM role name characters."
  }

  validation {
    condition = alltrue(flatten([
      for _, capability in var.capabilities : [
        for key in keys(capability.iam_policy_arn_map) :
        can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", key))
      ]
    ]))
    error_message = "capabilities[*].iam_policy_arn_map keys must be stable identifiers containing only letters, numbers, periods, underscores, and hyphens."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      upper(capability.type) != "ARGOCD" || (
        capability.argocd != null &&
        capability.argocd.idc_instance_arn != null
      )
    ])
    error_message = "ARGOCD capabilities require an argocd object with idc_instance_arn set."
  }

  validation {
    condition = alltrue([
      for _, capability in var.capabilities :
      upper(capability.type) == "ARGOCD" || capability.argocd == null
    ])
    error_message = "Only ARGOCD capabilities may configure the argocd object."
  }

  validation {
    condition = alltrue(flatten([
      for _, capability in var.capabilities :
      capability.argocd == null ? [true] : [
        for mapping in capability.argocd.rbac_role_mappings :
        contains(["ADMIN", "EDITOR", "VIEWER"], mapping.role)
      ]
    ]))
    error_message = "capabilities[*].argocd.rbac_role_mappings role must be ADMIN, EDITOR, or VIEWER."
  }

  validation {
    condition = alltrue(flatten([
      for _, capability in var.capabilities :
      capability.argocd == null ? [true] : flatten([
        for mapping in capability.argocd.rbac_role_mappings : [
          for identity in mapping.identities :
          contains(["SSO_USER", "SSO_GROUP"], identity.type)
        ]
      ])
    ]))
    error_message = "capabilities[*].argocd.rbac_role_mappings identity type must be SSO_USER or SSO_GROUP."
  }
}

variable "karpenter" {
  description = "Optional EKS-side readiness settings for Karpenter. This module prepares AWS/EKS primitives only; install Karpenter, controller IAM, interruption handling, NodePools, and EC2NodeClasses separately."
  type = object({
    create_access_entry        = optional(bool, true)
    create_node_iam_role       = optional(bool, true)
    enabled                    = optional(bool, false)
    node_iam_role_arn          = optional(string)
    node_iam_role_name         = optional(string)
    subnet_ids                 = optional(list(string), [])
    tag_cluster_security_group = optional(bool, true)
    tag_subnets                = optional(bool, true)
  })
  default = {}

  validation {
    condition = (
      !var.karpenter.enabled ||
      var.karpenter.create_node_iam_role ||
      var.karpenter.node_iam_role_arn != null
    )
    error_message = "When karpenter.enabled is true and create_node_iam_role is false, karpenter.node_iam_role_arn must be set."
  }

  validation {
    condition = (
      var.karpenter.node_iam_role_name == null ||
      can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.karpenter.node_iam_role_name))
    )
    error_message = "karpenter.node_iam_role_name must be 1-64 characters and contain only IAM role name characters."
  }
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}
