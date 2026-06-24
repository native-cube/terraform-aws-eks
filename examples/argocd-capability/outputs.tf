output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "argocd_server_url" {
  description = "Managed Argo CD server URL."
  value       = module.eks.argocd_server_url
}

output "argocd_capability_arn" {
  description = "Amazon EKS Argo CD capability ARN."
  value       = module.eks.argocd_capability_arn
}

output "argocd_capability_iam_role_arn" {
  description = "IAM role ARN used by the Amazon EKS Argo CD capability."
  value       = module.eks.argocd_capability_iam_role_arn
}

output "argocd_idc_managed_application_arn" {
  description = "IAM Identity Center managed application ARN created for the Argo CD capability."
  value       = module.eks.argocd_idc_managed_application_arn
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = module.eks.update_kubeconfig_command
}
