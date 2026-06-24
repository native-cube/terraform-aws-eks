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

variable "service_ipv4_cidr" {
  description = "Optional Kubernetes service IPv4 CIDR. Set only when you need a non-default service CIDR."
  type        = string
  default     = null
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
  description = "EKS add-ons to install after the managed node groups are created."
  type = map(object({
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

variable "argocd" {
  description = "Optional Amazon EKS Argo CD capability configuration. This creates the EKS managed Argo CD capability and, by default, a capability IAM role; it does not create Git repositories, Argo CD applications, or IAM Identity Center users/groups."
  type = object({
    capability_name           = optional(string, "argocd")
    create_iam_role           = optional(bool, true)
    delete_propagation_policy = optional(string, "RETAIN")
    enabled                   = optional(bool, false)
    iam_policy_arns           = optional(set(string), [])
    iam_role_arn              = optional(string)
    iam_role_name             = optional(string)
    idc_instance_arn          = optional(string)
    idc_region                = optional(string)
    inline_policy_json        = optional(string)
    namespace                 = optional(string)
    network_access_vpce_ids   = optional(set(string), [])
    rbac_role_mappings = optional(list(object({
      role = string
      identities = list(object({
        id   = string
        type = string
      }))
    })), [])
  })
  default = {}

  validation {
    condition = (
      !var.argocd.enabled ||
      var.argocd.create_iam_role ||
      var.argocd.iam_role_arn != null
    )
    error_message = "When argocd.enabled is true and create_iam_role is false, argocd.iam_role_arn must be set."
  }

  validation {
    condition = (
      !var.argocd.enabled ||
      var.argocd.idc_instance_arn != null
    )
    error_message = "When argocd.enabled is true, argocd.idc_instance_arn must be set."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,99}$", var.argocd.capability_name))
    error_message = "argocd.capability_name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
  }

  validation {
    condition     = var.argocd.delete_propagation_policy == "RETAIN"
    error_message = "argocd.delete_propagation_policy currently supports only RETAIN."
  }

  validation {
    condition = (
      var.argocd.iam_role_name == null ||
      can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.argocd.iam_role_name))
    )
    error_message = "argocd.iam_role_name must be 1-64 characters and contain only IAM role name characters."
  }

  validation {
    condition = alltrue([
      for mapping in var.argocd.rbac_role_mappings :
      contains(["ADMIN", "EDITOR", "VIEWER"], mapping.role)
    ])
    error_message = "argocd.rbac_role_mappings role must be ADMIN, EDITOR, or VIEWER."
  }

  validation {
    condition = alltrue(flatten([
      for mapping in var.argocd.rbac_role_mappings : [
        for identity in mapping.identities :
        contains(["SSO_USER", "SSO_GROUP"], identity.type)
      ]
    ]))
    error_message = "argocd.rbac_role_mappings identity type must be SSO_USER or SSO_GROUP."
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
