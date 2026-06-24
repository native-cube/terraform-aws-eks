variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "advanced"
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

variable "control_plane_subnet_ids" {
  description = "Existing subnet IDs for the EKS control plane."
  type        = list(string)
}

variable "cluster_security_group_ids" {
  description = "Additional security group IDs to associate with the EKS control plane."
  type        = list(string)
  default     = []
}

variable "node_group_subnet_ids" {
  description = "Optional subnet IDs for managed node groups. Defaults to control_plane_subnet_ids."
  type        = list(string)
  default     = []
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

variable "access_config" {
  description = "Optional EKS access configuration for cluster authentication mode and creator admin permissions."
  type = object({
    authentication_mode                         = optional(string)
    bootstrap_cluster_creator_admin_permissions = optional(bool)
  })
  default = {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection for the EKS cluster."
  type        = bool
  default     = true
}

variable "cluster_encryption_config" {
  description = "Optional EKS encryption configuration for Kubernetes secrets using an existing KMS key."
  type = object({
    provider_key_arn = string
    resources        = optional(list(string), ["secrets"])
  })
  default = null
}

variable "cloudwatch_log_retention_days" {
  description = "Retention in days for EKS control plane logs."
  type        = number
  default     = 90
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "Optional KMS key ID or ARN for encrypting the EKS control plane CloudWatch log group."
  type        = string
  default     = null
}

variable "service_ipv4_cidr" {
  description = "Optional Kubernetes service IPv4 CIDR."
  type        = string
  default     = null
}

variable "node_repair_config" {
  description = "Optional node repair configuration applied to both example managed node groups."
  type = object({
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
  })
  default = {
    enabled = true
  }
}

variable "ebs_csi_driver_service_account_role_arn" {
  description = "Optional IAM role ARN for the aws-ebs-csi-driver add-on. When null, the add-on is not installed by this example."
  type        = string
  default     = null
}

variable "efs_csi_driver_service_account_role_arn" {
  description = "Optional IAM role ARN for the aws-efs-csi-driver add-on. When null, the add-on is not installed by this example."
  type        = string
  default     = null
}

variable "cloudwatch_observability_service_account_role_arn" {
  description = "Optional IAM role ARN for the amazon-cloudwatch-observability add-on. When null, the add-on is not installed by this example."
  type        = string
  default     = null
}

variable "external_dns_service_account_role_arn" {
  description = "Optional IAM role ARN for the external-dns add-on. When null, the add-on is not installed by this example."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "advanced"
    ManagedBy   = "terraform"
  }
}
