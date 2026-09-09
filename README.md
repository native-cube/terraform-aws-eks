# Terraform AWS EKS Module

Official Terraform Registry module: [native-cube/eks/aws](https://registry.terraform.io/modules/native-cube/eks/aws/latest)

Simple Terraform module for creating an Amazon EKS cluster with:

- EKS control plane IAM role
- Managed node group IAM role
- One or more EKS managed node groups
- Optional EKS Auto Mode compute, load balancing, and block storage
- Optional hybrid capacity with Auto Mode and managed node groups in one cluster
- Optional EKS access entries and access policy associations
- Optional EKS Pod Identity associations
- Rendered Auto Mode NodeClass, NodePool, StorageClass, and LoadBalancer Service manifests
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
- `examples/auto-mode` - pure EKS Auto Mode cluster with public and private API access and no managed node groups or traditional add-on resources.
- `examples/basic` - simple explicit managed node group configuration.
- `examples/advanced` - restricted API access, full control-plane logging, multiple node groups, expanded add-on configuration, optional IAM-backed add-ons, and optional node subnet overrides.
- `examples/capabilities` - Amazon EKS managed capabilities for Argo CD, ACK, and KRO, including IAM Identity Center authentication for Argo CD and optional capability role policies.
- `examples/karpenter-ready` - EKS-side Karpenter readiness with discovery tags, a Karpenter node role, and node access entry while leaving the Karpenter controller, Helm release, interruption queue, NodePool, and EC2NodeClass to a separate module.
- `examples/provisioned-control-plane` - EKS Provisioned Control Plane configuration with a selectable scaling tier for predictable control-plane capacity.

## EKS Auto Mode

Auto Mode is opt-in. The default `auto_mode = null` preserves version 1.x behavior and does not manage Auto Mode settings. An empty object enables Auto Mode compute, load balancing, and block storage together with the built-in `general-purpose` and `system` node pools:

```hcl
module "eks" {
  source = "./eks"

  name       = "dev-auto"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  auto_mode = {}

  # Omit the standard module defaults for a pure Auto Mode cluster.
  node_groups = {}
  addons      = {}
}
```

`bootstrap_self_managed_addons` defaults to `null`. The module resolves that to `true` for a new standard cluster and `false` whenever an Auto Mode object is configured. EKS treats the setting as creation-time only, so the module ignores later changes on an existing cluster.

The Kubernetes API remains public and private by default. Restrict `public_access_cidrs` for production callers.

Keep `node_groups` populated to run a hybrid cluster while workloads move to Auto Mode. Standard managed nodes still need the traditional VPC CNI, `kube-proxy`, and CoreDNS add-ons. In a fresh hybrid configuration, set the module-managed VPC CNI to install before compute so managed nodes can bootstrap:

```hcl
auto_mode = {}

node_groups = {
  workloads = {}
}

addons = {
  vpc-cni = {
    before_compute = true
  }
  kube-proxy = {}
  coredns    = {}
  # Include eks-pod-identity-agent when standard nodes use Pod Identity.
}
```

`before_compute` defaults to `false`. Moving an existing module-managed `vpc-cni` add-on to the early phase changes its Terraform resource address; perform the state move in [MIGRATION-2.0.md](MIGRATION-2.0.md) before planning. AWS requires Auto Mode compute, load balancing, and block storage to be enabled or disabled together, so version 2.0 intentionally exposes one `auto_mode.enabled` switch rather than independent capability booleans.

Set `auto_mode.node_pools = []` to disable the built-in pools and use custom NodePools. With `auto_mode.create_access_entry = null` (the default), the module creates the required `EC2` access entry and `AmazonEKSAutoNodePolicy` association when a module-created or plan-known external Auto Mode node role is configured. Set this flag to `true` when an external `node_iam_role_arn` is unknown until apply, or to `false` when another stack owns that entry and association. `true` is valid only while Auto Mode is enabled, built-in pools are empty, and a module-created or external node role is configured. When a built-in pool is enabled, EKS owns the compute role's entry instead.

A custom NodeClass that names a different IAM role must also provide its ARN through `node_role_arn`. For a plan-known ARN, the nested `auto_mode_node_classes[*].create_access_entry` flag defaults to creating an entry keyed by the NodeClass name. Set that nested flag to `true` explicitly when the ARN comes from a resource created in the same plan. Give NodeClasses that share one custom role the same stable `access_entry_key` to deduplicate the entry; output keys use that value, or the NodeClass name by default. Set the nested flag to `false` when reusing the global/service-managed Auto Mode role or an externally managed entry.

When `auto_mode.create_node_iam_role = false`, the supplied role is externally owned. Before enabling compute, ensure that it trusts `ec2.amazonaws.com` for `sts:AssumeRole` and has `AmazonEKSWorkerNodeMinimalPolicy` plus `AmazonEC2ContainerRegistryPullOnly`, or equivalent permissions. The `auto_mode.node_iam_policy_arns` and `auto_mode.node_iam_policy_arn_map` inputs attach policies only to a role created by this module; they do not modify an external role.

Fresh configurations with either built-in pools or `node_pools = []` are supported. On an existing cluster, changing between empty and non-empty `node_pools` transfers the global node role's access-entry ownership between this module and EKS. Make that boundary change in a dedicated apply, wait for the EKS update, and verify that the role has one `EC2` entry with `AmazonEKSAutoNodePolicy` before proceeding. Test the transition against a live non-production cluster first. A distinct role for custom NodeClasses avoids transferring ownership of the built-in role's entry.

The module can render custom Kubernetes YAML without configuring a Kubernetes provider. Apply the combined output only after the cluster is reachable:

```bash
terraform output -raw auto_mode_kubernetes_manifest_yaml | kubectl apply -f -
```

To disable an enabled cluster safely, first apply `auto_mode = { enabled = false }`. After AWS finishes deleting Auto Mode compute and load balancers, set `auto_mode = null` in a second apply to remove retained Auto Mode IAM resources. Keep `access_config.authentication_mode` explicitly set to the cluster's current `API` or `API_AND_CONFIG_MAP` mode afterward; the transition away from `CONFIG_MAP` is one-way. For a cluster originally created for Auto Mode, keep `bootstrap_self_managed_addons = false` explicitly and permanently. If this module manages `vpc-cni` for managed node groups added later, set `before_compute = true`. Disabling Auto Mode is destructive; review AWS's [disable procedure](https://docs.aws.amazon.com/eks/latest/userguide/auto-disable.html) before changing an existing cluster.

## Access Entries and Pod Identity

Use `access_entries` to authorize IAM principals through EKS API authentication and optionally associate EKS access policies. When access entries are configured, the module defaults the authentication mode to `API`; existing `CONFIG_MAP` clusters should first move to `API_AND_CONFIG_MAP` as described in the migration guide.

On a legacy cluster, enabling the access-entry API automatically migrates only the original cluster creator. Before later changing to API-only authentication or removing `aws-auth` mappings, verify that EKS has created equivalent API access entries for every existing managed node group and Fargate role. Keep `API_AND_CONFIG_MAP` until that check passes. Do not add this module's managed-node role to `access_entries`; EKS owns that node identity and the module rejects duplicate principals.

Use `pod_identity_associations` to associate Kubernetes service accounts with existing IAM roles or module-created roles. Managed policy ARNs and inline JSON policies are supported for module-created roles. Auto Mode nodes include the Pod Identity agent. Standard managed nodes require the `eks-pod-identity-agent` add-on, so retain or add it while Pod Identity workloads run on those nodes in a hybrid cluster.

## Plan-safe IAM policy attachments

Use the keyed policy maps when a policy ARN comes from a resource or module created in the same plan. Stable caller-chosen keys let Terraform identify attachment instances before their ARN values are known:

```hcl
auto_mode = {
  cluster_iam_policy_arn_map = {
    custom_tags = aws_iam_policy.eks_auto_custom_tags.arn
  }
  node_iam_policy_arn_map = {
    node_access = aws_iam_policy.eks_auto_node_access.arn
  }
}

pod_identity_associations = {
  application = {
    namespace       = "application"
    service_account = "application"
    iam_policy_arn_map = {
      application_data = aws_iam_policy.application_data.arn
    }
  }
}

capabilities = {
  ack = {
    type = "ACK"
    iam_policy_arn_map = {
      ack_resources = aws_iam_policy.ack_resources.arn
    }
  }
}
```

The legacy `cluster_iam_policy_arns`, `node_iam_policy_arns`, and nested `iam_policy_arns` sets remain supported for literal or otherwise plan-known ARNs. Because set elements become `for_each` keys, every ARN in a set must be known during planning. Do not put the same policy in both the set and map forms.

Auto Mode's AWS-managed policies do not include arbitrary custom-resource tagging permissions. Custom worker security groups whose names do not match the EKS-created `eks-cluster-sg-*` pattern can also require extra cluster-role permissions so Auto Mode can add load-balancer ingress rules. Attach a least-privilege caller-managed policy through `auto_mode.cluster_iam_policy_arn_map`; see the AWS [Auto Mode networking considerations](https://docs.aws.amazon.com/eks/latest/userguide/auto-networking.html).

## Provisioned Control Plane

Set `control_plane_scaling_config` when a cluster needs predictable, pre-provisioned control-plane capacity. The component configuration arguments can customize the API server, controller manager, and scheduler:

```hcl
module "eks" {
  source = "./eks"

  name       = "performance-critical"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]

  control_plane_scaling_config = {
    tier = "tier-xl"
  }

  kube_api_server_config = {
    event_ttl = "30m"
    service_node_port_range = {
      min_port = 30000
      max_port = 32767
    }
  }

  kube_controller_manager_config = {
    horizontal_pod_autoscaler_controller_config = {
      horizontal_pod_autoscaler_sync_period = "10s"
    }
  }

  kube_scheduler_config = {
    node_resources_fit = {
      scoring_strategy = {
        type = "MostAllocated"
        resources = [
          { name = "cpu", weight = 1 },
          { name = "memory", weight = 1 }
        ]
      }
    }
  }
}
```

Supported tiers are `standard`, `tier-xl`, `tier-2xl`, `tier-4xl`, and `tier-8xl`. Leave the variable as `null` (the default) for standard control-plane behavior, or explicitly set `tier = "standard"` to move an existing Provisioned Control Plane cluster back to Standard mode. Provisioned tiers incur additional charges and remain pinned to the selected tier until reconfigured.

`kube_api_server_config.event_ttl` accepts 10–60 minutes, and the NodePort range must stay between ports 10260 and 32767. The controller manager HPA sync period accepts 10–15 seconds and requires a Provisioned Control Plane tier. Scheduler scoring supports `LeastAllocated` and `MostAllocated`, with optional resource weights from 1 to 100.

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

When enabled, the module can create a capability IAM role trusted by `capabilities.eks.amazonaws.com` and creates all configured entries through one `aws_eks_capability.this` resource block. Attach managed policies, an inline policy, or the `cloudcontrol_read_only`, `eks_read_only`, `resource_tagging`, and `secrets_read_only` presets only when a capability needs access to supporting AWS services.

The `secrets_read_only` and `resource_tagging` presets use `Resource = "*"`, so they grant broad permissions to matching resources in the account and Region. For production, prefer a caller-supplied `inline_policy_json` or managed policy scoped to the exact resource ARNs and actions the capability needs.

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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.59.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.59.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_tag.karpenter_cluster_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.karpenter_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eks_access_entry.auto_mode_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_entry.auto_mode_node_class](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_entry.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_entry.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.auto_mode_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_access_policy_association.auto_mode_node_class](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_access_policy_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_addon.before_compute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_capability.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_capability) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_eks_pod_identity_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.auto_mode_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.eks_capability_preset](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.auto_mode_cluster_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.auto_mode_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.auto_mode_node_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_capability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_config"></a> [access\_config](#input\_access\_config) | Optional EKS access configuration for cluster authentication mode and creator admin permissions. | <pre>object({<br/>    authentication_mode                         = optional(string)<br/>    bootstrap_cluster_creator_admin_permissions = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Additional EKS access entries and optional access policy associations to create. | <pre>map(object({<br/>    kubernetes_groups = optional(set(string), [])<br/>    policy_associations = optional(map(object({<br/>      access_scope = object({<br/>        namespaces = optional(set(string), [])<br/>        type       = string<br/>      })<br/>      policy_arn = string<br/>    })), {})<br/>    principal_arn = string<br/>    type          = optional(string, "STANDARD")<br/>    user_name     = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_addons"></a> [addons](#input\_addons) | EKS add-ons to install. Set before\_compute for add-ons such as vpc-cni that managed nodes need during bootstrap. | <pre>map(object({<br/>    before_compute       = optional(bool, false)<br/>    configuration_values = optional(string)<br/>    pod_identity_associations = optional(list(object({<br/>      role_arn        = string<br/>      service_account = string<br/>    })), [])<br/>    resolve_conflicts_on_create = optional(string, "OVERWRITE")<br/>    resolve_conflicts_on_update = optional(string, "OVERWRITE")<br/>    service_account_role_arn    = optional(string)<br/>    version                     = optional(string)<br/>  }))</pre> | <pre>{<br/>  "coredns": {},<br/>  "kube-proxy": {},<br/>  "vpc-cni": {}<br/>}</pre> | no |
| <a name="input_auto_mode"></a> [auto\_mode](#input\_auto\_mode) | Optional EKS Auto Mode configuration. Null leaves Auto Mode unmanaged for backward compatibility; an empty object enables Auto Mode with its default node pools. Set enabled to false to explicitly disable previously managed Auto Mode capabilities. | <pre>object({<br/>    cluster_iam_policy_arn_map = optional(map(string), {})<br/>    cluster_iam_policy_arns    = optional(set(string), [])<br/>    create_access_entry        = optional(bool)<br/>    create_node_iam_role       = optional(bool, true)<br/>    enabled                    = optional(bool, true)<br/>    node_iam_policy_arn_map    = optional(map(string), {})<br/>    node_iam_policy_arns       = optional(set(string), [])<br/>    node_iam_role_arn          = optional(string)<br/>    node_iam_role_name         = optional(string)<br/>    node_pools                 = optional(set(string), ["general-purpose", "system"])<br/>  })</pre> | `null` | no |
| <a name="input_auto_mode_load_balancer_services"></a> [auto\_mode\_load\_balancer\_services](#input\_auto\_mode\_load\_balancer\_services) | EKS Auto Mode Network Load Balancer Service manifests to render as YAML, keyed by Kubernetes metadata.name. | <pre>map(object({<br/>    annotations                 = optional(map(string), {})<br/>    external_traffic_policy     = optional(string)<br/>    ip_families                 = optional(list(string), [])<br/>    ip_family_policy            = optional(string)<br/>    labels                      = optional(map(string), {})<br/>    load_balancer_class         = optional(string, "eks.amazonaws.com/nlb")<br/>    load_balancer_source_ranges = optional(list(string), [])<br/>    namespace                   = optional(string, "default")<br/>    ports                       = list(any)<br/>    selector                    = map(string)<br/>    session_affinity            = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_auto_mode_node_classes"></a> [auto\_mode\_node\_classes](#input\_auto\_mode\_node\_classes) | Custom EKS Auto Mode NodeClass manifests to render as YAML, keyed by Kubernetes metadata.name. The module does not apply these manifests. | <pre>map(object({<br/>    access_entry_key    = optional(string)<br/>    annotations         = optional(map(string), {})<br/>    create_access_entry = optional(bool)<br/>    labels              = optional(map(string), {})<br/>    node_role_arn       = optional(string)<br/>    spec                = any<br/>  }))</pre> | `{}` | no |
| <a name="input_auto_mode_node_pools"></a> [auto\_mode\_node\_pools](#input\_auto\_mode\_node\_pools) | Custom EKS Auto Mode NodePool manifests to render as YAML, keyed by Kubernetes metadata.name. The module does not apply these manifests. | <pre>map(object({<br/>    annotations = optional(map(string), {})<br/>    labels      = optional(map(string), {})<br/>    spec        = any<br/>  }))</pre> | `{}` | no |
| <a name="input_auto_mode_storage_classes"></a> [auto\_mode\_storage\_classes](#input\_auto\_mode\_storage\_classes) | EKS Auto Mode EBS StorageClass manifests to render as YAML, keyed by Kubernetes metadata.name. | <pre>map(object({<br/>    allow_volume_expansion = optional(bool, true)<br/>    allowed_topologies     = optional(list(any), [])<br/>    annotations            = optional(map(string), {})<br/>    labels                 = optional(map(string), {})<br/>    mount_options          = optional(list(string), [])<br/>    parameters             = optional(map(string), {})<br/>    reclaim_policy         = optional(string, "Delete")<br/>    volume_binding_mode    = optional(string, "WaitForFirstConsumer")<br/>  }))</pre> | `{}` | no |
| <a name="input_bootstrap_self_managed_addons"></a> [bootstrap\_self\_managed\_addons](#input\_bootstrap\_self\_managed\_addons) | Whether EKS bootstraps self-managed networking add-ons at cluster creation. Leave null to derive true for standard clusters and false while Auto Mode is configured. This setting is create-only. | `bool` | `null` | no |
| <a name="input_capabilities"></a> [capabilities](#input\_capabilities) | Amazon EKS managed capabilities to create, keyed by a stable local name. Supported types are ARGOCD, ACK, and KRO. The module can create a capability IAM role per entry, or use an externally managed role ARN. | <pre>map(object({<br/>    capability_name           = optional(string)<br/>    create_iam_role           = optional(bool, true)<br/>    delete_propagation_policy = optional(string, "RETAIN")<br/>    iam_policy_arn_map        = optional(map(string), {})<br/>    iam_policy_arns           = optional(set(string), [])<br/>    iam_policy_presets        = optional(set(string), [])<br/>    iam_role_arn              = optional(string)<br/>    iam_role_name             = optional(string)<br/>    inline_policy_json        = optional(string)<br/>    type                      = string<br/>    argocd = optional(object({<br/>      idc_instance_arn        = optional(string)<br/>      idc_region              = optional(string)<br/>      namespace               = optional(string)<br/>      network_access_vpce_ids = optional(set(string), [])<br/>      rbac_role_mappings = optional(list(object({<br/>        role = string<br/>        identities = list(object({<br/>          id   = string<br/>          type = string<br/>        }))<br/>      })), [])<br/>    }))<br/>  }))</pre> | `{}` | no |
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
| <a name="input_force_update_version"></a> [force\_update\_version](#input\_force\_update\_version) | Whether to force a Kubernetes version update when EKS cannot drain pods. | `bool` | `null` | no |
| <a name="input_ip_family"></a> [ip\_family](#input\_ip\_family) | Optional Kubernetes service IP family. Valid values are ipv4 or ipv6. | `string` | `null` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Optional EKS-side readiness settings for Karpenter. This module prepares AWS/EKS primitives only; install Karpenter, controller IAM, interruption handling, NodePools, and EC2NodeClasses separately. | <pre>object({<br/>    create_access_entry        = optional(bool, true)<br/>    create_node_iam_role       = optional(bool, true)<br/>    enabled                    = optional(bool, false)<br/>    node_iam_role_arn          = optional(string)<br/>    node_iam_role_name         = optional(string)<br/>    subnet_ids                 = optional(list(string), [])<br/>    tag_cluster_security_group = optional(bool, true)<br/>    tag_subnets                = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_kube_api_server_config"></a> [kube\_api\_server\_config](#input\_kube\_api\_server\_config) | Optional Kubernetes API server configuration for event retention and the NodePort service range. | <pre>object({<br/>    event_ttl = optional(string)<br/>    service_node_port_range = optional(object({<br/>      max_port = optional(number)<br/>      min_port = optional(number)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_kube_controller_manager_config"></a> [kube\_controller\_manager\_config](#input\_kube\_controller\_manager\_config) | Optional Kubernetes controller manager configuration. HPA controller customization requires a Provisioned Control Plane tier. | <pre>object({<br/>    horizontal_pod_autoscaler_controller_config = optional(object({<br/>      horizontal_pod_autoscaler_sync_period = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_kube_scheduler_config"></a> [kube\_scheduler\_config](#input\_kube\_scheduler\_config) | Optional Kubernetes scheduler configuration for the NodeResourcesFit scoring strategy. | <pre>object({<br/>    node_resources_fit = optional(object({<br/>      scoring_strategy = optional(object({<br/>        resources = optional(list(object({<br/>          name   = optional(string)<br/>          weight = optional(number)<br/>        })), [])<br/>        type = optional(string)<br/>      }))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the EKS cluster and managed node groups. Leave null to use the current AWS default. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for module-created resources. Used as the EKS cluster name when cluster\_name is null. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Managed node groups to create. | <pre>map(object({<br/>    ami_type               = optional(string)<br/>    capacity_type          = optional(string, "ON_DEMAND")<br/>    desired_size           = optional(number, 2)<br/>    disk_size              = optional(number, 20)<br/>    instance_types         = optional(list(string), ["t3.medium"])<br/>    labels                 = optional(map(string), {})<br/>    max_size               = optional(number, 3)<br/>    min_size               = optional(number, 1)<br/>    subnet_ids             = optional(list(string), [])<br/>    update_max_unavailable = optional(number, 1)<br/>    node_repair_config = optional(object({<br/>      enabled                                 = optional(bool)<br/>      max_parallel_nodes_repaired_count       = optional(number)<br/>      max_parallel_nodes_repaired_percentage  = optional(number)<br/>      max_unhealthy_node_threshold_count      = optional(number)<br/>      max_unhealthy_node_threshold_percentage = optional(number)<br/>      overrides = optional(list(object({<br/>        min_repair_wait_time_mins = number<br/>        node_monitoring_condition = string<br/>        node_unhealthy_reason     = string<br/>        repair_action             = string<br/>      })), [])<br/>    }))<br/>    taints = optional(list(object({<br/>      effect = string<br/>      key    = string<br/>      value  = optional(string, "")<br/>    })), [])<br/>  }))</pre> | <pre>{<br/>  "default": {}<br/>}</pre> | no |
| <a name="input_pod_identity_associations"></a> [pod\_identity\_associations](#input\_pod\_identity\_associations) | EKS Pod Identity associations to create for Kubernetes service accounts. The module can create the IAM role per association, or use an externally managed role ARN. | <pre>map(object({<br/>    create_iam_role      = optional(bool, true)<br/>    disable_session_tags = optional(bool)<br/>    iam_policy_arn_map   = optional(map(string), {})<br/>    iam_policy_arns      = optional(set(string), [])<br/>    iam_role_arn         = optional(string)<br/>    iam_role_name        = optional(string)<br/>    inline_policy_json   = optional(string)<br/>    namespace            = string<br/>    service_account      = string<br/>    tags                 = optional(map(string), {})<br/>    target_role_arn      = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | CIDR blocks that can access the public Kubernetes API endpoint. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_service_ipv4_cidr"></a> [service\_ipv4\_cidr](#input\_service\_ipv4\_cidr) | Optional Kubernetes service IPv4 CIDR. Set only when you need a non-default service CIDR. | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the EKS control plane and default node groups. Use at least two subnets in different Availability Zones. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to created resources. | `map(string)` | `{}` | no |
| <a name="input_upgrade_policy_support_type"></a> [upgrade\_policy\_support\_type](#input\_upgrade\_policy\_support\_type) | Optional Kubernetes version support policy. Valid values are STANDARD and EXTENDED. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_entry_arns"></a> [access\_entry\_arns](#output\_access\_entry\_arns) | EKS access entry ARNs by access entry key. |
| <a name="output_addon_arns"></a> [addon\_arns](#output\_addon\_arns) | EKS add-on ARNs by add-on name. |
| <a name="output_argocd_idc_managed_application_arns"></a> [argocd\_idc\_managed\_application\_arns](#output\_argocd\_idc\_managed\_application\_arns) | IAM Identity Center managed application ARNs by ARGOCD capability key. |
| <a name="output_argocd_server_urls"></a> [argocd\_server\_urls](#output\_argocd\_server\_urls) | Managed Argo CD server URLs by ARGOCD capability key. |
| <a name="output_auto_mode_enabled"></a> [auto\_mode\_enabled](#output\_auto\_mode\_enabled) | Whether EKS Auto Mode is enabled by this module configuration. |
| <a name="output_auto_mode_kubernetes_manifest_yaml"></a> [auto\_mode\_kubernetes\_manifest\_yaml](#output\_auto\_mode\_kubernetes\_manifest\_yaml) | All rendered EKS Auto Mode Kubernetes manifests joined into a single multi-document YAML string. |
| <a name="output_auto_mode_kubernetes_manifests"></a> [auto\_mode\_kubernetes\_manifests](#output\_auto\_mode\_kubernetes\_manifests) | All rendered EKS Auto Mode Kubernetes YAML manifests by kind/name. |
| <a name="output_auto_mode_load_balancer_service_manifests"></a> [auto\_mode\_load\_balancer\_service\_manifests](#output\_auto\_mode\_load\_balancer\_service\_manifests) | Rendered EKS Auto Mode LoadBalancer Service YAML manifests by name. |
| <a name="output_auto_mode_node_access_entry_arn"></a> [auto\_mode\_node\_access\_entry\_arn](#output\_auto\_mode\_node\_access\_entry\_arn) | EKS access entry ARN created for the Auto Mode node role when built-in node pools are disabled. Built-in node pools register their role automatically. |
| <a name="output_auto_mode_node_class_access_entry_arns"></a> [auto\_mode\_node\_class\_access\_entry\_arns](#output\_auto\_mode\_node\_class\_access\_entry\_arns) | EKS access entry ARNs created for custom Auto Mode NodeClass IAM roles, keyed by access\_entry\_key (or NodeClass name by default). |
| <a name="output_auto_mode_node_class_manifests"></a> [auto\_mode\_node\_class\_manifests](#output\_auto\_mode\_node\_class\_manifests) | Rendered EKS Auto Mode NodeClass YAML manifests by name. |
| <a name="output_auto_mode_node_iam_role_arn"></a> [auto\_mode\_node\_iam\_role\_arn](#output\_auto\_mode\_node\_iam\_role\_arn) | IAM role ARN used by EKS Auto Mode managed compute when Auto Mode is configured. |
| <a name="output_auto_mode_node_iam_role_name"></a> [auto\_mode\_node\_iam\_role\_name](#output\_auto\_mode\_node\_iam\_role\_name) | IAM role name used by EKS Auto Mode managed compute when Auto Mode is configured. |
| <a name="output_auto_mode_node_pool_manifests"></a> [auto\_mode\_node\_pool\_manifests](#output\_auto\_mode\_node\_pool\_manifests) | Rendered EKS Auto Mode NodePool YAML manifests by name. |
| <a name="output_auto_mode_storage_class_manifests"></a> [auto\_mode\_storage\_class\_manifests](#output\_auto\_mode\_storage\_class\_manifests) | Rendered EKS Auto Mode StorageClass YAML manifests by name. |
| <a name="output_capability_arns"></a> [capability\_arns](#output\_capability\_arns) | Amazon EKS capability ARNs by capability key. |
| <a name="output_capability_iam_policy_preset_names"></a> [capability\_iam\_policy\_preset\_names](#output\_capability\_iam\_policy\_preset\_names) | Capability IAM policy preset names attached by capability key. |
| <a name="output_capability_iam_role_arns"></a> [capability\_iam\_role\_arns](#output\_capability\_iam\_role\_arns) | IAM role ARNs used by Amazon EKS capabilities by capability key. |
| <a name="output_capability_iam_role_names"></a> [capability\_iam\_role\_names](#output\_capability\_iam\_role\_names) | IAM role names used by Amazon EKS capabilities by capability key. |
| <a name="output_capability_names"></a> [capability\_names](#output\_capability\_names) | Amazon EKS capability names by capability key. |
| <a name="output_capability_versions"></a> [capability\_versions](#output\_capability\_versions) | Amazon EKS capability software versions by capability key. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS cluster ARN. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded cluster certificate authority data. |
| <a name="output_cluster_created_at"></a> [cluster\_created\_at](#output\_cluster\_created\_at) | Timestamp when the EKS cluster was created. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API server endpoint. |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN used by the EKS control plane. |
| <a name="output_cluster_log_group_name"></a> [cluster\_log\_group\_name](#output\_cluster\_log\_group\_name) | CloudWatch log group for EKS control plane logs, if cluster logs are enabled. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name. |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | OIDC issuer URL for the EKS cluster. |
| <a name="output_cluster_platform_version"></a> [cluster\_platform\_version](#output\_cluster\_platform\_version) | EKS platform version. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group created by EKS for the cluster. |
| <a name="output_cluster_status"></a> [cluster\_status](#output\_cluster\_status) | EKS cluster status. |
| <a name="output_cluster_tags_all"></a> [cluster\_tags\_all](#output\_cluster\_tags\_all) | All tags applied to the EKS cluster, including provider default tags. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version running on the EKS cluster. |
| <a name="output_karpenter_discovery_tag_key"></a> [karpenter\_discovery\_tag\_key](#output\_karpenter\_discovery\_tag\_key) | Tag key used by Karpenter discovery selectors when Karpenter readiness is enabled. |
| <a name="output_karpenter_discovery_tag_value"></a> [karpenter\_discovery\_tag\_value](#output\_karpenter\_discovery\_tag\_value) | Tag value used by Karpenter discovery selectors when Karpenter readiness is enabled. |
| <a name="output_karpenter_node_iam_role_arn"></a> [karpenter\_node\_iam\_role\_arn](#output\_karpenter\_node\_iam\_role\_arn) | IAM role ARN for Karpenter-launched worker nodes when Karpenter readiness is enabled. |
| <a name="output_karpenter_node_iam_role_name"></a> [karpenter\_node\_iam\_role\_name](#output\_karpenter\_node\_iam\_role\_name) | IAM role name for Karpenter EC2NodeClass role configuration when Karpenter readiness is enabled. |
| <a name="output_node_group_arns"></a> [node\_group\_arns](#output\_node\_group\_arns) | Managed node group ARNs by node group key. |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | IAM role ARN used by managed node groups. |
| <a name="output_pod_identity_association_arns"></a> [pod\_identity\_association\_arns](#output\_pod\_identity\_association\_arns) | EKS Pod Identity association ARNs by association key. |
| <a name="output_pod_identity_association_ids"></a> [pod\_identity\_association\_ids](#output\_pod\_identity\_association\_ids) | EKS Pod Identity association IDs by association key. |
| <a name="output_pod_identity_external_ids"></a> [pod\_identity\_external\_ids](#output\_pod\_identity\_external\_ids) | External IDs generated for EKS Pod Identity associations by association key. |
| <a name="output_pod_identity_iam_role_arns"></a> [pod\_identity\_iam\_role\_arns](#output\_pod\_identity\_iam\_role\_arns) | IAM role ARNs used by EKS Pod Identity associations by association key. |
| <a name="output_pod_identity_iam_role_names"></a> [pod\_identity\_iam\_role\_names](#output\_pod\_identity\_iam\_role\_names) | IAM role names used by EKS Pod Identity associations by association key. |
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
