variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "advanced-eks"
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

variable "cloudwatch_log_retention_days" {
  description = "Retention in days for EKS control plane logs."
  type        = number
  default     = 90
}

variable "service_ipv4_cidr" {
  description = "Optional Kubernetes service IPv4 CIDR."
  type        = string
  default     = null
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
