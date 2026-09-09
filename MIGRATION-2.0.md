# Migrating to version 2.0

Version 2.0 adds EKS Auto Mode to `terraform-aws-eks` while retaining the existing managed-node-group behavior. The `auto_mode` input defaults to `null`, so upgrading an existing standard EKS deployment does not enable Auto Mode implicitly.

The Kubernetes API endpoint remains public and private by default. The public endpoint allows `0.0.0.0/0` by default; production configurations should set `public_access_cidrs` explicitly.

This guide covers:

- upgrading a standard cluster from `terraform-aws-eks` v1.x;
- enabling Auto Mode on an existing standard cluster.

## Before upgrading

1. Upgrade the current configuration to its latest applicable v1.x release and apply it so that the starting plan is clean.
2. Check that the root configuration can use AWS provider `>= 6.59.0`.
3. Back up the Terraform state and confirm that the backup can be accessed by the team responsible for recovery.
4. Test the migration against a non-production cluster first.
5. Record the current EKS endpoint, authentication mode, `bootstrap_cluster_creator_admin_permissions` value, IP family, service CIDR, node groups, add-ons, access entries, Pod Identity associations, storage classes, and load balancers.

For a local state file, a backup can be captured with:

```bash
terraform state pull > terraform-state-before-eks-v2.json
```

Store state backups according to your security policy because state can contain sensitive values. Do not commit the backup.

## 1. Upgrade `terraform-aws-eks` from v1.x to v2.x

Change only the module version first. Keep the module block label unchanged:

```hcl
module "eks" {
  source  = "<your terraform-aws-eks source>"
  version = "2.0.0"

  name       = "production"
  subnet_ids = var.eks_subnet_ids

  # Optional: null is the v2 default and leaves Auto Mode unmanaged.
  auto_mode = null

  # Make the existing public endpoint behavior explicit during the upgrade.
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs      = var.eks_public_access_cidrs
}
```

Then initialize and inspect the plan:

```bash
terraform init -upgrade
terraform validate
terraform plan
```

No state moves are expected when the module block label is unchanged. Version 2.0 preserves the standard cluster, cluster IAM role, managed-node IAM role, managed node group, add-on, log group, capability, and Karpenter resource addresses used by v1.x.

The following standard-cluster defaults also remain unchanged:

- `auto_mode = null`, which does not enable or disable Auto Mode;
- `bootstrap_self_managed_addons = null`, which resolves to `true` when Auto Mode is not configured;
- a `default` EKS managed node group when `node_groups` is omitted;
- the `coredns`, `kube-proxy`, and `vpc-cni` EKS add-ons when `addons` is omitted; and
- public and private Kubernetes API access, with `public_access_cidrs = ["0.0.0.0/0"]`.

Stop and investigate if a normal v1.x-to-v2.0 plan proposes replacing the EKS cluster or existing managed node groups.

### Immutable network settings

Treat `ip_family` and `service_ipv4_cidr` as creation-time settings. The AWS provider marks both attributes `ForceNew`, so any planned difference forces replacement of `aws_eks_cluster.this`. Do not use the v2.0 upgrade as an opportunity to change them unless replacing the cluster is intentional.

Auto Mode supports IPv6, but `service_ipv4_cidr` is incompatible with `ip_family = "ipv6"`. For IPv6, omit `service_ipv4_cidr`; EKS assigns the IPv6 service range. EKS does not support changing a cluster's IP family after creation.

### Renaming the module block

Renaming a module block changes every Terraform address below it. Avoid the rename during the version upgrade when possible. If a rename is required, move the module state before planning. For example:

```bash
terraform state mv 'module.eks_old' 'module.eks'
```

Adjust both addresses when the module uses `count`, `for_each`, or is nested under another module. Run `terraform state list` before and after the move, then confirm the plan contains no unintended destroys.

## 2. Enable Auto Mode on an existing standard cluster

Enable Auto Mode separately from the v2.0 version upgrade so each plan has one clear purpose.

### Phase 1: enable access-entry authentication

Auto Mode requires an API-capable authentication mode. Before adding `auto_mode`, inspect the existing cluster's `access_config` in Terraform state or with `aws eks describe-cluster`. Record the current `bootstrap_cluster_creator_admin_permissions` value; changing this creation-time value can force replacement of the cluster.

If the cluster currently uses `CONFIG_MAP`, make `API_AND_CONFIG_MAP` the only functional change in a separate first apply. Explicitly preserve the cluster's current bootstrap creator permission. For example, when its current value is `true`:

```hcl
module "eks" {
  source  = "<your terraform-aws-eks source>"
  version = "2.0.0"

  name       = "production"
  subnet_ids = var.eks_subnet_ids

  auto_mode = null

  access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs      = var.eks_public_access_cidrs
}
```

Use `false` instead if that is the cluster's current bootstrap permission. Apply this authentication-mode transition and wait for the cluster update to finish before creating access entries or enabling Auto Mode. The transition away from `CONFIG_MAP` is one-way, so confirm equivalent administrator and automation access through `access_entries` before later removing `aws-auth` mappings. Clusters already using `API_AND_CONFIG_MAP` or `API` do not need this preliminary mode transition, but should still preserve the current bootstrap permission explicitly.

Enabling the access-entry API on a legacy cluster automatically migrates only the original cluster creator. Before any later move to API-only authentication or removal of EKS-owned `aws-auth` mappings:

1. List the cluster's API access entries and inspect `aws-auth` for existing managed node group and Fargate role mappings.
2. Confirm that an equivalent EKS-managed API access entry exists for every such role; otherwise keep `API_AND_CONFIG_MAP` and complete that service-managed migration first.
3. Do not add this module's managed-node role to `access_entries`. EKS owns that node identity, and the module rejects duplicate principals.

```bash
terraform plan -out=eks-auth-mode.tfplan
terraform apply eks-auth-mode.tfplan
```

### Phase 2: enable Auto Mode in a hybrid configuration

After API authentication is active, verify any installed Amazon VPC CNI, `kube-proxy`, Amazon EBS CSI driver, CSI snapshot controller, and EKS Pod Identity Agent against AWS's [current required add-on versions for enabling Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-enable-existing.html). Follow the live AWS table rather than pinning the values from this guide.

Auto Mode nodes include the Pod Identity agent, but standard managed nodes do not. If `pod_identity_associations` serve workloads that remain on managed node groups during the hybrid phase, retain or add `eks-pod-identity-agent` in `addons` until those workloads have moved off the standard nodes.

Then enable Auto Mode and add the required human and automation principals through `access_entries`. Retain the existing node groups and add-ons during workload migration:

```hcl
module "eks" {
  source  = "<your terraform-aws-eks source>"
  version = "2.0.0"

  name       = "production"
  subnet_ids = var.eks_subnet_ids

  auto_mode = {}

  access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true # Match the existing cluster.
  }

  access_entries = var.eks_access_entries

  # Keep managed-node capacity and required traditional add-ons during the
  # hybrid migration. Preserve every existing add-on and its configuration.
  node_groups = var.node_groups
  addons = merge(var.addons, {
    vpc-cni = merge(var.addons["vpc-cni"], {
      before_compute = true
    })
  })

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs      = var.eks_public_access_cidrs
}
```

For every fresh hybrid configuration where this module manages `vpc-cni`, `before_compute = true` is required so the CNI is ready before managed node groups bootstrap. Other add-ons default to the post-compute phase with `before_compute = false`.

On an existing v1.x or v2.0 state, changing `vpc-cni` to `before_compute = true` moves it from one Terraform resource block to another. After editing the configuration but before running `terraform plan`, back up state and move the existing instance:

```bash
terraform state mv \
  'module.eks.aws_eks_addon.this["vpc-cni"]' \
  'module.eks.aws_eks_addon.before_compute["vpc-cni"]'
```

Adjust the module path for the caller. Skip the move if the module does not manage `vpc-cni`, the state address is absent, or it is already under `aws_eks_addon.before_compute`. Confirm the subsequent plan updates the existing add-on rather than destroying and recreating it.

An empty `auto_mode` object enables compute with the built-in `general-purpose` and `system` node pools. EKS-managed compute, load balancing, and block storage are enabled together to meet the EKS API and AWS provider invariant.

By default, the module creates the Auto Mode node IAM role. If `auto_mode.create_node_iam_role = false`, verify the supplied external role before enabling Auto Mode. It must trust `ec2.amazonaws.com` for `sts:AssumeRole` and have `AmazonEKSWorkerNodeMinimalPolicy` plus `AmazonEC2ContainerRegistryPullOnly`, or equivalent permissions. The `auto_mode.node_iam_policy_arns` and `auto_mode.node_iam_policy_arn_map` inputs apply only to a module-created role and do not modify an external role.

Create and review a saved plan before applying:

```bash
terraform plan -out=eks-auto-mode.tfplan
terraform show eks-auto-mode.tfplan
```

The plan should update the existing cluster in place, update the cluster-role trust policy for Auto Mode, attach the required Auto Mode cluster policies, and create the dedicated Auto Mode node role and policies when the module owns that role. Stop if it proposes replacing the cluster or existing managed node groups. Once the review is complete, apply the saved plan and wait for the EKS update to finish:

```bash
terraform apply eks-auto-mode.tfplan
```

Once enabled with built-in node pools, the effective Auto Mode compute `node_role_arn` is a cluster creation-time setting in the AWS provider. Changing it forces replacement of `aws_eks_cluster.this`. This includes switching between a module-created and external role, changing `auto_mode.node_iam_role_arn`, or renaming a module-created role so its ARN changes. Stop if such a plan proposes cluster replacement and migrate to a new cluster unless replacement is intentional.

`bootstrap_self_managed_addons` is nullable in version 2.0. Its `null` default resolves to `true` when `auto_mode = null` and to `false` whenever an `auto_mode` object is configured. The setting is creation-time only, and the module ignores changes after creation. Consequently, enabling Auto Mode on an existing standard cluster does not rewrite its current value.

With a built-in node pool, EKS creates the access entry for the compute node role as part of the service-managed configuration; the module deliberately does not create a duplicate. A custom `NodeClass` that reuses that compute role reuses the service-created access entry. When all built-in node pools are disabled with `node_pools = []`, `auto_mode.create_access_entry = null` (the default) makes the module create an `EC2` entry and `AmazonEKSAutoNodePolicy` association for a module-created or plan-known external Auto Mode role. Set this flag to `true` when an external `node_iam_role_arn` is unknown until apply so Terraform can determine the resource count during planning. Set it to `false` only when another stack owns the required entry and association. `true` requires enabled Auto Mode, no built-in pools, and a module-created or external node role; built-in pools always use the EKS-owned entry.

A custom `NodeClass` that uses a different role must set `node_role_arn`. When that ARN is known during planning, leaving the nested `auto_mode_node_classes[*].create_access_entry = null` automatically creates the role's `EC2` access entry and associates `AmazonEKSAutoNodePolicy`. Set the nested flag to `true` explicitly when the ARN comes from a resource created in the same plan, because Terraform must know the access-entry collection during planning. Set it to `false` when reusing the global Auto Mode compute role or an access entry managed elsewhere. Access resources use the NodeClass name as their key by default; give NodeClasses that share one custom role the same stable `access_entry_key` to create only one entry and association.

On an existing cluster, a later change between empty and non-empty `node_pools` transfers ownership of the global node role's access entry between Terraform and EKS. Isolate that change in its own plan and apply, wait for the cluster update to complete, then verify that exactly one `EC2` entry exists for the role and that `AmazonEKSAutoNodePolicy` is associated before continuing. Exercise this transition on a live non-production cluster first; mock plans cannot validate the service-side handoff. Prefer a distinct custom NodeClass role and module-managed entry when ownership ambiguity is unacceptable.

The AWS-managed Auto Mode policies do not allow arbitrary user-defined tags on provisioned EC2, EBS, and load-balancing resources. When custom `NodeClass`, storage, or load-balancer configuration applies custom AWS tags, create a least-privilege policy for those tag keys. If the policy is created in the same plan, pass its ARN through the plan-safe map:

```hcl
auto_mode = {
  cluster_iam_policy_arn_map = {
    custom_tags = aws_iam_policy.eks_auto_custom_tags.arn
  }
}
```

The module attaches these caller-managed policies to the cluster IAM role; it does not create their policy documents. Custom worker security groups outside the EKS-created `eks-cluster-sg-*` naming pattern can similarly require additional cluster-role permissions so Auto Mode can add load-balancer ingress rules. Supply those permissions through `cluster_iam_policy_arn_map` and review AWS's [Auto Mode networking guidance](https://docs.aws.amazon.com/eks/latest/userguide/auto-networking.html). See the AWS [Auto Mode cluster IAM role guidance](https://docs.aws.amazon.com/eks/latest/userguide/auto-cluster-iam-role.html) for custom-tag permissions.

Use `auto_mode.cluster_iam_policy_arn_map` and `auto_mode.node_iam_policy_arn_map`, or nested `pod_identity_associations[*].iam_policy_arn_map` and `capabilities[*].iam_policy_arn_map`, when values come from resources or modules created in the same plan. Their stable caller-chosen keys are known early enough for `for_each`. The corresponding legacy `_arns` sets remain supported for literal, imported, or otherwise plan-known ARNs; every set element must be known during planning because the ARN itself becomes the attachment key. Do not configure the same policy through both forms.

Existing self-managed Karpenter and AWS Load Balancer Controller installations may overlap with Auto Mode only during a controlled transition. Explicitly migrate ownership of Karpenter `NodePool`/`EC2NodeClass` resources and load-balanced Kubernetes `Service` resources; do not leave legacy and Auto Mode controllers competing for the same resources long term. Remove each legacy controller only after its workloads and AWS resources have moved and the Auto Mode replacement is healthy. AWS's [existing-cluster migration guidance](https://docs.aws.amazon.com/eks/latest/userguide/migrate-auto.html) describes the supported ownership transitions and resources that cannot be transferred directly.

After Auto Mode capacity is healthy:

1. Move workloads in controlled batches and validate scheduling, disruption budgets, networking, storage, observability, and autoscaling.
2. Confirm which controller owns every load balancer and storage volume. Existing load balancers and EBS-backed workloads are not converted merely by enabling Auto Mode.
3. Drain the old managed node groups only after replacement capacity is ready.
4. Set `node_groups = {}` and `addons = {}` only when it is safe for Terraform to destroy those managed node groups and add-ons.

A pure Auto Mode configuration is:

```hcl
auto_mode  = {}
node_groups = {}
addons      = {}
```

The module retains its legacy managed-node IAM role resource for v1.x state compatibility, even when `node_groups = {}`. No EKS managed node group uses that role in a pure Auto Mode configuration.

### Verify Auto Mode

After applying, verify:

```bash
aws eks describe-cluster --name <cluster-name>
aws eks update-kubeconfig --name <cluster-name>
kubectl get nodes
kubectl get nodeclasses
kubectl get nodepools
```

Also confirm that intended access entries and Pod Identity associations remain present, workloads are healthy, and public API access is limited to the expected CIDRs.

Custom manifest inputs continue to produce YAML outputs; Terraform does not apply those Kubernetes manifests. Reconcile the rendered `NodeClass`, `NodePool`, `StorageClass`, and load-balancer `Service` YAML through the deployment process that owns in-cluster resources.
