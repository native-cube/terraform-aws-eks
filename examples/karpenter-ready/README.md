# Karpenter-Ready Example

This example prepares only the EKS side of a Karpenter deployment:

- Creates an EKS cluster with API access entries enabled.
- Creates a small managed node group for bootstrap and system workloads.
- Installs core EKS add-ons and `eks-pod-identity-agent`.
- Creates a dedicated IAM role for Karpenter-launched worker nodes.
- Authorizes that node role with an EKS `EC2_LINUX` access entry.
- Tags selected subnets and the EKS-created cluster security group with `karpenter.sh/discovery`.

It intentionally does not install Karpenter, create the Karpenter controller IAM role, create an interruption queue, or manage `NodePool` and `EC2NodeClass` resources. A separate Karpenter module or Helm release should consume this example's Karpenter outputs.

Provide existing subnet IDs before planning or applying:

```bash
terraform init
terraform plan -var='subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

If subnet ownership lives in a network module, set `tag_karpenter_subnets = false` and apply the same discovery tag there instead.
