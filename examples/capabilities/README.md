# EKS Capabilities Example

This example creates an EKS cluster and enables all Amazon EKS managed capability types currently supported by the module:

- `ARGOCD` for managed Argo CD.
- `ACK` for AWS Controllers for Kubernetes.
- `KRO` for Kube Resource Orchestrator.

It requires:

- Existing subnet IDs for the cluster and managed node group.
- An IAM Identity Center instance ARN for Argo CD authentication.
- Optionally, an IAM Identity Center group ID to map to the Argo CD `ADMIN` role.
- Optionally, VPC endpoint IDs to make the managed Argo CD server private-only.
- Optional managed or inline IAM policies per capability role. The exact policies depend on what Argo CD, ACK, or KRO should access or manage.

```hcl
module "eks" {
  source = "../.."

  name       = "example-capabilities"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  capabilities = {
    argocd = {
      type = "ARGOCD"
      argocd = {
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

    ack = {
      type = "ACK"
    }

    kro = {
      type = "KRO"
    }
  }
}
```

After apply, use `capability_arns` to inspect the created capabilities and `argocd_server_url` to open the managed Argo CD UI.
