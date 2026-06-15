variable "name" {
  description = "Name of the EKS cluster."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-_]{0,99}$", var.name))
    error_message = "The cluster name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
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
    configuration_values        = optional(string)
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

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}
