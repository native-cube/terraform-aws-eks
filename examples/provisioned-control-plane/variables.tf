variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "provisioned-control-plane"
}

variable "cluster_name" {
  description = "Optional EKS cluster name. When null, name is used as the cluster name."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Existing subnet IDs for the EKS control plane and managed node group."
  type        = list(string)
}

variable "control_plane_scaling_tier" {
  description = "EKS control plane scaling tier. Use standard to leave Provisioned mode."
  type        = string
  default     = "tier-xl"

  validation {
    condition     = contains(["standard", "tier-xl", "tier-2xl", "tier-4xl", "tier-8xl"], var.control_plane_scaling_tier)
    error_message = "control_plane_scaling_tier must be standard, tier-xl, tier-2xl, tier-4xl, or tier-8xl."
  }
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
