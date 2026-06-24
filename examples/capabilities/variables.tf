variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name prefix for module-created resources."
  type        = string
  default     = "example-capabilities"
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

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "identity_center_instance_arn" {
  description = "IAM Identity Center instance ARN used for Argo CD authentication."
  type        = string
}

variable "identity_center_region" {
  description = "Region where the IAM Identity Center instance exists. Leave null when it matches the provider region."
  type        = string
  default     = null
}

variable "argocd_admin_group_id" {
  description = "Optional IAM Identity Center group ID to grant Argo CD ADMIN access."
  type        = string
  default     = null
}

variable "argocd_private_vpce_ids" {
  description = "Optional VPC endpoint IDs for private-only access to the managed Argo CD server. When empty, AWS exposes the default public endpoint."
  type        = set(string)
  default     = []
}

variable "argocd_capability_iam_policy_arns" {
  description = "Optional managed IAM policy ARNs to attach to the Argo CD capability role for integrations such as Secrets Manager, CodeConnections, or ECR."
  type        = set(string)
  default     = []
}

variable "argocd_capability_inline_policy_json" {
  description = "Optional inline IAM policy JSON for the Argo CD capability role."
  type        = string
  default     = null
}

variable "ack_capability_iam_policy_arns" {
  description = "Optional managed IAM policy ARNs to attach to the ACK capability role for the AWS resources ACK controllers should manage."
  type        = set(string)
  default     = []
}

variable "ack_capability_inline_policy_json" {
  description = "Optional inline IAM policy JSON for the ACK capability role."
  type        = string
  default     = null
}

variable "kro_capability_iam_policy_arns" {
  description = "Optional managed IAM policy ARNs to attach to the KRO capability role for the AWS resources KRO should orchestrate."
  type        = set(string)
  default     = []
}

variable "kro_capability_inline_policy_json" {
  description = "Optional inline IAM policy JSON for the KRO capability role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "example"
  }
}
