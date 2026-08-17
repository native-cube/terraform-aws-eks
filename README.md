# Terraform AWS EKS Module

Simple Terraform module for creating an Amazon EKS cluster with:

- EKS control plane IAM role
- Managed node group IAM role
- One or more EKS managed node groups
- Optional EKS Provisioned Control Plane scaling tiers
- Core EKS add-ons: `coredns`, `kube-proxy`, and `vpc-cni`
- Optional Amazon EKS managed capabilities: Argo CD, ACK, and KRO
- Optional EKS-side Karpenter readiness without installing Karpenter itself
- Useful connection and composition outputs

The module expects you to provide existing subnet IDs. In most deployments these should be private subnets with outbound internet access through NAT.

## Usage

```hcl
module "eks" {
  source = "./eks"

  name         = "dev"
  cluster_name = "dev-eks"
  subnet_ids   = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      desired_size   = 2
      max_size       = 3
    }
  }

  tags = {
    Environment = "dev"
  }
}
```

Then configure `kubectl`:

```bash
aws eks update-kubeconfig --name dev-eks
```

## Examples

- `examples/minimal` - smallest practical module call using defaults for node groups, add-ons, API access, and logging.
- `examples/basic` - simple explicit managed node group configuration.
- `examples/advanced` - restricted API access, full control-plane logging, multiple node groups, expanded add-on configuration, optional IAM-backed add-ons, and optional node subnet overrides.
- `examples/capabilities` - Amazon EKS managed capabilities for Argo CD, ACK, and KRO, including IAM Identity Center authentication for Argo CD and optional capability role policies.
- `examples/karpenter-ready` - EKS-side Karpenter readiness with discovery tags, a Karpenter node role, and node access entry while leaving the Karpenter controller, Helm release, interruption queue, NodePool, and EC2NodeClass to a separate module.
- `examples/provisioned-control-plane` - EKS Provisioned Control Plane configuration with a selectable scaling tier for predictable control-plane capacity.

## Provisioned Control Plane

Set `control_plane_scaling_config` when a cluster needs predictable, pre-provisioned control-plane capacity:

```hcl
module "eks" {
  source = "./eks"

  name       = "performance-critical"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  control_plane_scaling_config = {
    tier = "tier-xl"
  }
}
```

Supported tiers are `standard`, `tier-xl`, `tier-2xl`, `tier-4xl`, and `tier-8xl`. Leave the variable as `null` (the default) for standard control-plane behavior, or explicitly set `tier = "standard"` to move an existing Provisioned Control Plane cluster back to Standard mode. Provisioned tiers incur additional charges and remain pinned to the selected tier until reconfigured.

## EKS Capabilities

Enable the `capabilities` map when this module should create Amazon EKS managed capabilities. Supported types are `ARGOCD`, `ACK`, and `KRO`.

```hcl
module "eks" {
  source = "./eks"

  name       = "dev"
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
      type            = "KRO"
      create_iam_role = false
      iam_role_arn    = "arn:aws:iam::123456789012:role/platform/KROCapabilityRole"
    }
  }
}
```

When enabled, the module can create a capability IAM role trusted by `capabilities.eks.amazonaws.com` and creates all configured entries through one `aws_eks_capability.this` resource block. Attach managed policies or an inline policy to the capability role only when a capability needs access to supporting AWS services.

For `ARGOCD`, configure the nested `argocd` object with IAM Identity Center settings, optional RBAC role mappings, and optional VPC endpoint IDs. If `argocd.network_access_vpce_ids` is empty, AWS exposes the default public managed Argo CD endpoint. Supplying VPC endpoint IDs makes the Argo CD server private-only through those endpoints.

## Karpenter Readiness

Enable the `karpenter` object when this module should prepare the cluster for Karpenter-managed capacity:

```hcl
module "eks" {
  source = "./eks"

  name       = "dev"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  karpenter = {
    enabled              = true
    create_node_iam_role = true
    create_access_entry  = true
  }
}
```

When enabled, the module can create the worker-node IAM role used by Karpenter-launched EC2 instances, authorize that role with an EKS `EC2_LINUX` access entry, and tag selected subnets plus the EKS-created cluster security group with `karpenter.sh/discovery = <cluster_name>`.

This module deliberately does not install the Karpenter controller, create its controller IAM role, create an interruption queue, or manage `NodePool` and `EC2NodeClass` resources. Use the `karpenter_*` outputs as inputs to that separate layer.

## Module Documentation

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.39.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.39.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_tag.karpenter_cluster_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.karpenter_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eks_access_entry.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_capability.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_config"></a> [access\_config](#input\_access\_config) | Optional EKS access configuration for cluster authentication mode and creator admin permissions. | <pre>object({<br/>    authentication_mode                         = optional(string)<br/>    bootstrap_cluster_creator_admin_permissions = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_addons"></a> [addons](#input\_addons) | EKS add-ons to install after the managed node groups are created. | <pre>map(object({<br/>    configuration_values = optional(string)<br/>    pod_identity_associations = optional(list(object({<br/>      role_arn        = string<br/>      service_account = string<br/>    })), [])<br/>    resolve_conflicts_on_create = optional(string, "OVERWRITE")<br/>    resolve_conflicts_on_update = optional(string, "OVERWRITE")<br/>    service_account_role_arn    = optional(string)<br/>    version                     = optional(string)<br/>  }))</pre> | <pre>{<br/>  "coredns": {},<br/>  "kube-proxy": {},<br/>  "vpc-cni": {}<br/>}</pre> | no |
| <a name="input_capabilities"></a> [capabilities](#input\_capabilities) | Amazon EKS managed capabilities to create, keyed by a stable local name. Supported types are ARGOCD, ACK, and KRO. The module can create a capability IAM role per entry, or use an externally managed role ARN. | <pre>map(object({<br/>    capability_name           = optional(string)<br/>    create_iam_role           = optional(bool, true)<br/>    delete_propagation_policy = optional(string, "RETAIN")<br/>    iam_policy_arns           = optional(set(string), [])<br/>    iam_role_arn              = optional(string)<br/>    iam_role_name             = optional(string)<br/>    inline_policy_json        = optional(string)<br/>    type                      = string<br/>    argocd = optional(object({<br/>      idc_instance_arn        = optional(string)<br/>      idc_region              = optional(string)<br/>      namespace               = optional(string)<br/>      network_access_vpce_ids = optional(set(string), [])<br/>      rbac_role_mappings = optional(list(object({<br/>        role = string<br/>        identities = list(object({<br/>          id   = string<br/>          type = string<br/>        }))<br/>      })), [])<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_cloudwatch_log_group_kms_key_id"></a> [cloudwatch\_log\_group\_kms\_key\_id](#input\_cloudwatch\_log\_group\_kms\_key\_id) | Optional KMS key ID or ARN for encrypting the EKS control plane CloudWatch log group. | `string` | `null` | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | Retention in days for the EKS control plane CloudWatch log group. | `number` | `30` | no |
| <a name="input_cluster_encryption_config"></a> [cluster\_encryption\_config](#input\_cluster\_encryption\_config) | Optional EKS encryption configuration for Kubernetes secrets using an existing KMS key. | <pre>object({<br/>    provider_key_arn = string<br/>    resources        = optional(list(string), ["secrets"])<br/>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Optional EKS cluster name. When null, name is used as the cluster name. | `string` | `null` | no |
| <a name="input_cluster_security_group_ids"></a> [cluster\_security\_group\_ids](#input\_cluster\_security\_group\_ids) | Additional security group IDs to associate with the EKS control plane. | `list(string)` | `[]` | no |
| <a name="input_control_plane_scaling_config"></a> [control\_plane\_scaling\_config](#input\_control\_plane\_scaling\_config) | Optional EKS Provisioned Control Plane scaling configuration. Leave null to use the standard control plane scaling tier. | <pre>object({<br/>    tier = string<br/>  })</pre> | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection for the EKS cluster. Leave null to use the AWS/provider default. | `bool` | `null` | no |
| <a name="input_enabled_cluster_log_types"></a> [enabled\_cluster\_log\_types](#input\_enabled\_cluster\_log\_types) | EKS control plane log types to enable. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator"<br/>]</pre> | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Whether the Kubernetes API server endpoint is reachable from within the VPC. | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Whether the Kubernetes API server endpoint is reachable from the public internet. | `bool` | `true` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Optional EKS-side readiness settings for Karpenter. This module prepares AWS/EKS primitives only; install Karpenter, controller IAM, interruption handling, NodePools, and EC2NodeClasses separately. | <pre>object({<br/>    create_access_entry        = optional(bool, true)<br/>    create_node_iam_role       = optional(bool, true)<br/>    enabled                    = optional(bool, false)<br/>    node_iam_role_arn          = optional(string)<br/>    node_iam_role_name         = optional(string)<br/>    subnet_ids                 = optional(list(string), [])<br/>    tag_cluster_security_group = optional(bool, true)<br/>    tag_subnets                = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the EKS cluster and managed node groups. Leave null to use the current AWS default. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for module-created resources. Used as the EKS cluster name when cluster\_name is null. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Managed node groups to create. | <pre>map(object({<br/>    ami_type               = optional(string)<br/>    capacity_type          = optional(string, "ON_DEMAND")<br/>    desired_size           = optional(number, 2)<br/>    disk_size              = optional(number, 20)<br/>    instance_types         = optional(list(string), ["t3.medium"])<br/>    labels                 = optional(map(string), {})<br/>    max_size               = optional(number, 3)<br/>    min_size               = optional(number, 1)<br/>    subnet_ids             = optional(list(string), [])<br/>    update_max_unavailable = optional(number, 1)<br/>    node_repair_config = optional(object({<br/>      enabled                                 = optional(bool)<br/>      max_parallel_nodes_repaired_count       = optional(number)<br/>      max_parallel_nodes_repaired_percentage  = optional(number)<br/>      max_unhealthy_node_threshold_count      = optional(number)<br/>      max_unhealthy_node_threshold_percentage = optional(number)<br/>      overrides = optional(list(object({<br/>        min_repair_wait_time_mins = number<br/>        node_monitoring_condition = string<br/>        node_unhealthy_reason     = string<br/>        repair_action             = string<br/>      })), [])<br/>    }))<br/>    taints = optional(list(object({<br/>      effect = string<br/>      key    = string<br/>      value  = optional(string, "")<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "default": {}<br/>}</pre> | no |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | CIDR blocks that can access the public Kubernetes API endpoint. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_service_ipv4_cidr"></a> [service\_ipv4\_cidr](#input\_service\_ipv4\_cidr) | Optional Kubernetes service IPv4 CIDR. Set only when you need a non-default service CIDR. | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the EKS control plane and default node groups. Use at least two subnets in different Availability Zones. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addon_arns"></a> [addon\_arns](#output\_addon\_arns) | EKS add-on ARNs by add-on name. |
| <a name="output_argocd_idc_managed_application_arns"></a> [argocd\_idc\_managed\_application\_arns](#output\_argocd\_idc\_managed\_application\_arns) | IAM Identity Center managed application ARNs by ARGOCD capability key. |
| <a name="output_argocd_server_urls"></a> [argocd\_server\_urls](#output\_argocd\_server\_urls) | Managed Argo CD server URLs by ARGOCD capability key. |
| <a name="output_capability_arns"></a> [capability\_arns](#output\_capability\_arns) | Amazon EKS capability ARNs by capability key. |
| <a name="output_capability_iam_role_arns"></a> [capability\_iam\_role\_arns](#output\_capability\_iam\_role\_arns) | IAM role ARNs used by Amazon EKS capabilities by capability key. |
| <a name="output_capability_iam_role_names"></a> [capability\_iam\_role\_names](#output\_capability\_iam\_role\_names) | IAM role names used by Amazon EKS capabilities by capability key. |
| <a name="output_capability_names"></a> [capability\_names](#output\_capability\_names) | Amazon EKS capability names by capability key. |
| <a name="output_capability_versions"></a> [capability\_versions](#output\_capability\_versions) | Amazon EKS capability software versions by capability key. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS cluster ARN. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded cluster certificate authority data. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API server endpoint. |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN used by the EKS control plane. |
| <a name="output_cluster_log_group_name"></a> [cluster\_log\_group\_name](#output\_cluster\_log\_group\_name) | CloudWatch log group for EKS control plane logs, if cluster logs are enabled. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | OIDC issuer URL for the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group created by EKS for the cluster. |
| <a name="output_karpenter_discovery_tag_key"></a> [karpenter\_discovery\_tag\_key](#output\_karpenter\_discovery\_tag\_key) | Tag key used by Karpenter discovery selectors when Karpenter readiness is enabled. |
| <a name="output_karpenter_discovery_tag_value"></a> [karpenter\_discovery\_tag\_value](#output\_karpenter\_discovery\_tag\_value) | Tag value used by Karpenter discovery selectors when Karpenter readiness is enabled. |
| <a name="output_karpenter_node_iam_role_arn"></a> [karpenter\_node\_iam\_role\_arn](#output\_karpenter\_node\_iam\_role\_arn) | IAM role ARN for Karpenter-launched worker nodes when Karpenter readiness is enabled. |
| <a name="output_karpenter_node_iam_role_name"></a> [karpenter\_node\_iam\_role\_name](#output\_karpenter\_node\_iam\_role\_name) | IAM role name for Karpenter EC2NodeClass role configuration when Karpenter readiness is enabled. |
| <a name="output_node_group_arns"></a> [node\_group\_arns](#output\_node\_group\_arns) | Managed node group ARNs by node group key. |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | IAM role ARN used by managed node groups. |
| <a name="output_update_kubeconfig_command"></a> [update\_kubeconfig\_command](#output\_update\_kubeconfig\_command) | AWS CLI command to configure kubectl for this cluster. |
<!-- END_TF_DOCS -->

## Git Hooks

Enable the repository hooks after cloning or initializing Git:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook checks Terraform formatting and verifies that generated Terraform docs in this README are up to date.

Regenerate the README module documentation manually with:

```bash
scripts/terraform-docs.sh
```

## Tests

Native Terraform tests live in `tests/` and use mocked AWS provider resources, so they can run without AWS credentials or creating infrastructure:

```bash
terraform test
```

Pull requests run the same tests through `.github/workflows/terraform-pr.yml`, along with formatting, generated-docs, validation, and example checks.

## Local Development

Use the Makefile for common local checks:

```bash
make fmt
make docs
make check
```

## Notes

- The module does not create VPC, subnet, route table, NAT gateway, or security baseline resources.
- For production use, restrict `public_access_cidrs` instead of leaving the default `0.0.0.0/0`.
- Node group subnets default to `subnet_ids`, but each node group can override them with its own `subnet_ids`.
