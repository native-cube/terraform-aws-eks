output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "argocd_server_url" {
  description = "Managed Argo CD server URL."
  value       = try(module.eks.argocd_server_urls["argocd"], null)
}

output "argocd_capability_arn" {
  description = "Amazon EKS Argo CD capability ARN."
  value       = try(module.eks.capability_arns["argocd"], null)
}

output "argocd_capability_iam_role_arn" {
  description = "IAM role ARN used by the Amazon EKS Argo CD capability."
  value       = try(module.eks.capability_iam_role_arns["argocd"], null)
}

output "argocd_idc_managed_application_arn" {
  description = "IAM Identity Center managed application ARN created for the Argo CD capability."
  value       = try(module.eks.argocd_idc_managed_application_arns["argocd"], null)
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = module.eks.update_kubeconfig_command
}
