# EKS Auto Mode Example

This example creates an EKS cluster that uses Auto Mode for compute, load balancing, and block storage. It enables the EKS built-in `general-purpose` and `system` node pools and deliberately sets both `node_groups` and `addons` to empty maps.

Because an Auto Mode object is configured, the nullable `bootstrap_self_managed_addons` input resolves to `false` when this new cluster is created. EKS treats that setting as creation-time only.

The Kubernetes API endpoint is public and private. The example defaults `public_access_cidrs` to `0.0.0.0/0` for ease of evaluation; production callers should replace that value with the narrowest CIDRs that need API access.

Provide at least two existing subnet IDs in different Availability Zones before planning:

```bash
terraform init
terraform plan \
  -var='subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]' \
  -var='public_access_cidrs=["203.0.113.10/32"]'
```

After applying the plan, configure `kubectl` with the rendered command:

```bash
terraform output -raw update_kubeconfig_command
```

The module can also render custom Auto Mode `NodeClass`, `NodePool`, `StorageClass`, and load-balancer `Service` YAML through `auto_mode_node_classes`, `auto_mode_node_pools`, `auto_mode_storage_classes`, and `auto_mode_load_balancer_services`. It returns the YAML as outputs but does not apply it, because the module does not configure a Kubernetes provider.

Set `access_entries` to grant principals access through the EKS API authentication mode. Set `pod_identity_associations` when workloads need EKS Pod Identity; the module can create a role for an association or use an existing role. Auto Mode nodes include the Pod Identity agent, so this pure Auto Mode example does not need the `eks-pod-identity-agent` add-on. Hybrid clusters must retain or add that add-on for Pod Identity workloads running on standard managed nodes. A fresh hybrid configuration must also set `addons["vpc-cni"].before_compute = true`; moving an existing add-on to that phase requires the state move documented in [`MIGRATION-2.0.md`](../../MIGRATION-2.0.md).

EKS creates the access entry for the node role used by the built-in node pools. The module does not create a duplicate. A custom `NodeClass` using a separate IAM role should set `node_role_arn`; for a plan-known ARN, the module automatically creates an `EC2` access entry and `AmazonEKSAutoNodePolicy` association keyed by the NodeClass name. Set `create_access_entry = true` explicitly when the ARN comes from a resource created in the same plan. Give NodeClasses sharing one role the same stable `access_entry_key` to create one shared entry; the output uses that key. Set `create_access_entry = false` when reusing the built-in compute role or an entry managed elsewhere.

After Auto Mode is enabled with built-in node pools, any planned change to its effective compute node role ARN forces EKS cluster replacement. Keep the role ARN stable for the cluster's lifetime.

AWS-managed Auto Mode policies do not grant permission to propagate arbitrary user-defined tags to provisioned AWS resources. Use a plan-safe map when the policy is created alongside the cluster:

```hcl
auto_mode = {
  cluster_iam_policy_arn_map = {
    custom_tags = aws_iam_policy.eks_auto_custom_tags.arn
  }
}
```

Use `cluster_iam_policy_arns` only for ARNs already known during planning. The same map/set distinction applies to `auto_mode.node_iam_policy_arn_map`/`node_iam_policy_arns` and to `iam_policy_arn_map`/`iam_policy_arns` in Pod Identity and capability entries.

Custom worker security groups outside the EKS-created `eks-cluster-sg-*` naming pattern can require additional cluster-role permissions for Auto Mode to add load-balancer ingress rules. Supply a least-privilege policy through `cluster_iam_policy_arn_map` and review AWS's [Auto Mode networking guidance](https://docs.aws.amazon.com/eks/latest/userguide/auto-networking.html).

Choose the network family only when creating the cluster. The provider marks `ip_family` and `service_ipv4_cidr` `ForceNew`, so any planned difference forces replacement of the EKS cluster. Auto Mode supports IPv6, but `service_ipv4_cidr` cannot be set with `ip_family = "ipv6"`; omit it and let EKS assign the IPv6 service range.

Disabling Auto Mode requires two applies and destroys Auto Mode-managed compute and load balancers. Review AWS's [disable procedure](https://docs.aws.amazon.com/eks/latest/userguide/auto-disable.html) before changing an enabled cluster to `auto_mode = null`, and keep `bootstrap_self_managed_addons = false` permanently for this Auto-created cluster.
