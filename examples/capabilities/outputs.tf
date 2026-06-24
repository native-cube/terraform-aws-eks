output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "capability_arns" {
  description = "Amazon EKS capability ARNs by capability key."
  value       = module.eks.capability_arns
}

output "capability_versions" {
  description = "Amazon EKS capability software versions by capability key."
  value       = module.eks.capability_versions
}

output "capability_iam_role_arns" {
  description = "IAM role ARNs used by Amazon EKS capabilities by capability key."
  value       = module.eks.capability_iam_role_arns
}

output "argocd_server_url" {
  description = "Managed Argo CD server URL."
  value       = try(module.eks.argocd_server_urls["argocd"], null)
}

output "argocd_idc_managed_application_arn" {
  description = "IAM Identity Center managed application ARN created for the Argo CD capability."
  value       = try(module.eks.argocd_idc_managed_application_arns["argocd"], null)
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = module.eks.update_kubeconfig_command
}
