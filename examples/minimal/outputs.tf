output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl."
  value       = module.eks.update_kubeconfig_command
}
