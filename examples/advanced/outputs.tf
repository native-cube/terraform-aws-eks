output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group created by EKS for the cluster."
  value       = module.eks.cluster_security_group_id
}

output "cluster_log_group_name" {
  description = "CloudWatch log group for EKS control plane logs."
  value       = module.eks.cluster_log_group_name
}

output "node_group_arns" {
  description = "Managed node group ARNs by node group key."
  value       = module.eks.node_group_arns
}

output "addon_arns" {
  description = "EKS add-on ARNs by add-on name."
  value       = module.eks.addon_arns
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl."
  value       = module.eks.update_kubeconfig_command
}
