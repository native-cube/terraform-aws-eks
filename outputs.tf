output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_created_at" {
  description = "Timestamp when the EKS cluster was created."
  value       = aws_eks_cluster.this.created_at
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

output "cluster_platform_version" {
  description = "EKS platform version."
  value       = aws_eks_cluster.this.platform_version
}

output "cluster_status" {
  description = "EKS cluster status."
  value       = aws_eks_cluster.this.status
}

output "cluster_tags_all" {
  description = "All tags applied to the EKS cluster, including provider default tags."
  value       = aws_eks_cluster.this.tags_all
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS cluster."
  value       = aws_eks_cluster.this.version
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by managed node groups."
  value       = aws_iam_role.node.arn
}

output "auto_mode_enabled" {
  description = "Whether EKS Auto Mode is enabled by this module configuration."
  value       = local.auto_mode_enabled
}

output "auto_mode_node_iam_role_arn" {
  description = "IAM role ARN used by EKS Auto Mode managed compute when Auto Mode is configured."
  value       = local.auto_mode_configured ? local.auto_mode_node_iam_role_arn : null
}

output "auto_mode_node_iam_role_name" {
  description = "IAM role name used by EKS Auto Mode managed compute when Auto Mode is configured."
  value       = local.auto_mode_configured ? local.auto_mode_node_iam_role_name : null
}

output "auto_mode_node_access_entry_arn" {
  description = "EKS access entry ARN created for the Auto Mode node role when built-in node pools are disabled. Built-in node pools register their role automatically."
  value       = try(aws_eks_access_entry.auto_mode_node[0].access_entry_arn, null)
}

output "access_entry_arns" {
  description = "EKS access entry ARNs by access entry key."
  value       = { for key, entry in aws_eks_access_entry.this : key => entry.access_entry_arn }
}

output "auto_mode_node_class_access_entry_arns" {
  description = "EKS access entry ARNs created for custom Auto Mode NodeClass IAM roles, keyed by access_entry_key (or NodeClass name by default)."
  value       = { for key, entry in aws_eks_access_entry.auto_mode_node_class : key => entry.access_entry_arn }
}

output "auto_mode_node_class_manifests" {
  description = "Rendered EKS Auto Mode NodeClass YAML manifests by name."
  value       = local.auto_mode_node_class_manifests
}

output "auto_mode_node_pool_manifests" {
  description = "Rendered EKS Auto Mode NodePool YAML manifests by name."
  value       = local.auto_mode_node_pool_manifests
}

output "auto_mode_storage_class_manifests" {
  description = "Rendered EKS Auto Mode StorageClass YAML manifests by name."
  value       = local.auto_mode_storage_class_manifests
}

output "auto_mode_load_balancer_service_manifests" {
  description = "Rendered EKS Auto Mode LoadBalancer Service YAML manifests by name."
  value       = local.auto_mode_load_balancer_service_manifests
}

output "auto_mode_kubernetes_manifests" {
  description = "All rendered EKS Auto Mode Kubernetes YAML manifests by kind/name."
  value       = local.auto_mode_kubernetes_manifests
}

output "auto_mode_kubernetes_manifest_yaml" {
  description = "All rendered EKS Auto Mode Kubernetes manifests joined into a single multi-document YAML string."
  value       = length(local.auto_mode_kubernetes_manifests) == 0 ? "" : join("---\n", values(local.auto_mode_kubernetes_manifests))
}

output "pod_identity_association_arns" {
  description = "EKS Pod Identity association ARNs by association key."
  value       = { for key, association in aws_eks_pod_identity_association.this : key => association.association_arn }
}

output "pod_identity_association_ids" {
  description = "EKS Pod Identity association IDs by association key."
  value       = { for key, association in aws_eks_pod_identity_association.this : key => association.association_id }
}

output "pod_identity_external_ids" {
  description = "External IDs generated for EKS Pod Identity associations by association key."
  value       = { for key, association in aws_eks_pod_identity_association.this : key => association.external_id }
}

output "pod_identity_iam_role_arns" {
  description = "IAM role ARNs used by EKS Pod Identity associations by association key."
  value       = local.pod_identity_iam_role_arns
}

output "pod_identity_iam_role_names" {
  description = "IAM role names used by EKS Pod Identity associations by association key."
  value       = local.pod_identity_iam_role_names
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

output "capability_iam_policy_preset_names" {
  description = "Capability IAM policy preset names attached by capability key."
  value       = { for key, capability in local.eks_capability_configs : key => capability.iam_policy_presets }
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
  value = merge(
    { for key, addon in aws_eks_addon.before_compute : key => addon.arn },
    { for key, addon in aws_eks_addon.this : key => addon.arn }
  )
}

output "update_kubeconfig_command" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name}"
}
