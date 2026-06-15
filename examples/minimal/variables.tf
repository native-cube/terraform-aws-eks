variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "minimal-eks"
}

variable "subnet_ids" {
  description = "Existing subnet IDs for EKS. Prefer private subnets with NAT egress."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Environment = "minimal"
  }
}
