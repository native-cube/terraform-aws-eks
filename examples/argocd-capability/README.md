# Argo CD Capability Example

This example creates an EKS cluster and enables the Amazon EKS managed Argo CD capability.

It requires:

- Existing subnet IDs for the cluster and managed node group.
- An IAM Identity Center instance ARN for Argo CD authentication.
- Optionally, an IAM Identity Center group ID to map to the Argo CD `ADMIN` role.
- Optionally, VPC endpoint IDs to make the managed Argo CD server private-only.
- Optionally, managed IAM policies for the capability role when Argo CD needs access to services such as Secrets Manager, CodeConnections, or ECR.

```hcl
module "eks" {
  source = "../.."

  name       = "example-argocd"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  argocd = {
    enabled          = true
    idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
    namespace        = "argocd"
    rbac_role_mappings = [
      {
        role = "ADMIN"
        identities = [
          {
            id   = "12345678-1234-1234-1234-123456789012"
            type = "SSO_GROUP"
          }
        ]
      }
    ]
  }
}
```

After apply, use the `argocd_server_url` output to open the managed Argo CD UI.
