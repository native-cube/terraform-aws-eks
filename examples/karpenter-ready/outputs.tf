output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster certificate authority data."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA-based Karpenter controller IAM if used by the separate Karpenter module."
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "Security group created by EKS for the cluster."
  value       = module.eks.cluster_security_group_id
}

output "karpenter_discovery_tag_key" {
  description = "Tag key for Karpenter subnet and security group selectors."
  value       = module.eks.karpenter_discovery_tag_key
}

output "karpenter_discovery_tag_value" {
  description = "Tag value for Karpenter subnet and security group selectors."
  value       = module.eks.karpenter_discovery_tag_value
}

output "karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-launched worker nodes."
  value       = module.eks.karpenter_node_iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name to use as EC2NodeClass spec.role."
  value       = module.eks.karpenter_node_iam_role_name
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl."
  value       = module.eks.update_kubeconfig_command
}
