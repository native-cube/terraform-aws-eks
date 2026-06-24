variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "example"
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
  description = "Existing subnet IDs for EKS. Prefer private subnets with NAT egress."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "example"
  }
}
