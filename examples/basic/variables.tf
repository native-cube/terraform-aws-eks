variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "example-eks"
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
