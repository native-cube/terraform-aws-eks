variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "karpenter-ready"
}

variable "cluster_name" {
  description = "Optional EKS cluster name. When null, name is used as the cluster name."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Optional Kubernetes version. Leave null to use the AWS default."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Existing subnet IDs for the EKS control plane and bootstrap system node group."
  type        = list(string)
}

variable "karpenter_subnet_ids" {
  description = "Optional subnet IDs to tag for Karpenter discovery. Defaults to subnet_ids."
  type        = list(string)
  default     = []
}

variable "tag_karpenter_subnets" {
  description = "Whether this module call should tag selected subnets for Karpenter discovery. Set false when network ownership lives elsewhere."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server endpoint is reachable from the public internet."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can reach the public Kubernetes API endpoint. Replace the default placeholder before applying."
  type        = list(string)
  default     = ["203.0.113.10/32"]
}

variable "system_node_instance_types" {
  description = "Instance types for the bootstrap system managed node group."
  type        = list(string)
  default     = ["m7i.large"]
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "karpenter-ready"
    ManagedBy   = "terraform"
  }
}
