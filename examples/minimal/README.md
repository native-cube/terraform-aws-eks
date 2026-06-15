# Minimal Example

Smallest practical use of the module. It creates an EKS cluster with the module defaults:

- Public and private Kubernetes API endpoint access.
- A default managed node group.
- Core EKS add-ons.
- Default control-plane log types and retention.

Provide existing subnet IDs before planning or applying:

```bash
terraform init
terraform plan -var='subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

Set `cluster_name` when the EKS cluster name should differ from the module resource prefix in `name`.
