variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "example-auto-mode"
}

variable "cluster_name" {
  description = "Optional EKS cluster name. When null, name is used as the cluster name."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. Leave null to use the current AWS default."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Existing subnet IDs for the EKS control plane and Auto Mode compute. Prefer private subnets with NAT egress."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint. Restrict this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "example"
    Example     = "auto-mode"
  }
}
