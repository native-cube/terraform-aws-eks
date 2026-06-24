output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group created by EKS for the cluster."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_log_group_name" {
  description = "CloudWatch log group for EKS control plane logs, if cluster logs are enabled."
  value       = try(aws_cloudwatch_log_group.cluster[0].name, null)
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by managed node groups."
  value       = aws_iam_role.node.arn
}

output "capability_arns" {
  description = "Amazon EKS capability ARNs by capability key."
  value       = { for key, capability in aws_eks_capability.this : key => capability.arn }
}

output "capability_names" {
  description = "Amazon EKS capability names by capability key."
  value       = { for key, capability in aws_eks_capability.this : key => capability.capability_name }
}

output "capability_versions" {
  description = "Amazon EKS capability software versions by capability key."
  value       = { for key, capability in aws_eks_capability.this : key => capability.version }
}

output "capability_iam_role_arns" {
  description = "IAM role ARNs used by Amazon EKS capabilities by capability key."
  value       = local.eks_capability_iam_role_arns
}

output "capability_iam_role_names" {
  description = "IAM role names used by Amazon EKS capabilities by capability key."
  value       = local.eks_capability_iam_role_names
}

output "argocd_server_urls" {
  description = "Managed Argo CD server URLs by ARGOCD capability key."
  value = {
    for key, capability in aws_eks_capability.this : key => try(capability.configuration[0].argo_cd[0].server_url, null)
    if local.eks_capability_configs[key].type == "ARGOCD"
  }
}

output "argocd_idc_managed_application_arns" {
  description = "IAM Identity Center managed application ARNs by ARGOCD capability key."
  value = {
    for key, capability in aws_eks_capability.this : key => try(capability.configuration[0].argo_cd[0].aws_idc[0].idc_managed_application_arn, null)
    if local.eks_capability_configs[key].type == "ARGOCD"
  }
}

output "karpenter_discovery_tag_key" {
  description = "Tag key used by Karpenter discovery selectors when Karpenter readiness is enabled."
  value       = local.karpenter_enabled ? local.karpenter_discovery_tag_key : null
}

output "karpenter_discovery_tag_value" {
  description = "Tag value used by Karpenter discovery selectors when Karpenter readiness is enabled."
  value       = local.karpenter_enabled ? local.karpenter_discovery_tag_value : null
}

output "karpenter_node_iam_role_arn" {
  description = "IAM role ARN for Karpenter-launched worker nodes when Karpenter readiness is enabled."
  value       = local.karpenter_enabled ? local.karpenter_node_role_arn : null
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name for Karpenter EC2NodeClass role configuration when Karpenter readiness is enabled."
  value       = local.karpenter_enabled ? local.karpenter_node_role_name_out : null
}

output "node_group_arns" {
  description = "Managed node group ARNs by node group key."
  value       = { for key, node_group in aws_eks_node_group.this : key => node_group.arn }
}

output "addon_arns" {
  description = "EKS add-on ARNs by add-on name."
  value       = { for key, addon in aws_eks_addon.this : key => addon.arn }
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name}"
}
