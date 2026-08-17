# Provisioned Control Plane Example

This example creates an EKS cluster with a Provisioned Control Plane scaling tier for predictable control-plane capacity. It configures `tier-xl` by default; set `control_plane_scaling_tier` to `tier-2xl`, `tier-4xl`, or `tier-8xl` when the workload needs a larger tier.

Provisioned tiers incur additional charges and do not scale automatically between tiers. Standard mode is appropriate for most clusters. Set `control_plane_scaling_tier = "standard"` to return the cluster to standard control-plane scaling. See the [Amazon EKS Provisioned Control Plane documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-provisioned-control-plane.html) for tier capacity, Kubernetes version support, regional availability, and pricing considerations.

Provide existing subnet IDs before planning or applying:

```bash
terraform init
terraform plan \
  -var='subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]' \
  -var='control_plane_scaling_tier=tier-xl'
```
