mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"eks.amazonaws.com\"},\"Action\":[\"sts:AssumeRole\",\"sts:TagSession\"]}]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/mock-eks-role"
      name = "mock-eks-role"
    }
  }
}

run "standard_mode_remains_the_default" {
  command = plan

  variables {
    name = "unit-standard-v2"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]
  }

  assert {
    condition     = length(aws_eks_cluster.this.compute_config) == 0
    error_message = "Omitting auto_mode must not add an Auto Mode compute configuration to an existing standard cluster."
  }

  assert {
    condition     = length(aws_eks_cluster.this.storage_config) == 0
    error_message = "Omitting auto_mode must not add an Auto Mode storage configuration to an existing standard cluster."
  }

  assert {
    condition     = aws_eks_cluster.this.bootstrap_self_managed_addons == true
    error_message = "Standard clusters must continue bootstrapping self-managed add-ons by default."
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 0
    error_message = "Omitting auto_mode must not create an Auto Mode node IAM role."
  }

  assert {
    condition     = output.auto_mode_enabled == false && output.auto_mode_node_iam_role_arn == null
    error_message = "Auto Mode outputs must remain disabled and null for existing standard callers."
  }

  assert {
    condition     = !contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2")
    error_message = "Omitting auto_mode must not add Auto Mode policies to the cluster role."
  }

  assert {
    condition     = toset(keys(aws_eks_node_group.this)) == toset(["default"])
    error_message = "The standard module must retain its default managed node group."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.this)) == toset(["coredns", "kube-proxy", "vpc-cni"])
    error_message = "The standard module must retain its default EKS add-ons."
  }

  assert {
    condition     = length(aws_eks_addon.before_compute) == 0
    error_message = "Standard default add-ons must retain their post-compute ordering."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "The standard cluster API endpoint must remain public by default."
  }
}

run "auto_only_cluster_shape" {
  command = plan

  variables {
    name = "unit-auto-only"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode   = {}
    node_groups = {}
    addons      = {}
  }

  assert {
    condition     = aws_eks_cluster.this.bootstrap_self_managed_addons == false
    error_message = "An Auto-only cluster must not bootstrap the legacy self-managed add-ons."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Auto Mode must derive API authentication when access_config is omitted."
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == true
    error_message = "Auto Mode compute must be enabled."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.compute_config[0].node_pools) == toset(["general-purpose", "system"])
    error_message = "Auto Mode must enable the general-purpose and system built-in node pools by default."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].elastic_load_balancing[0].enabled == true
    error_message = "Auto Mode load balancing must be enabled with Auto Mode compute."
  }

  assert {
    condition     = aws_eks_cluster.this.storage_config[0].block_storage[0].enabled == true
    error_message = "Auto Mode block storage must be enabled with Auto Mode compute."
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 1
    error_message = "Auto Mode must create a dedicated node IAM role by default."
  }

  assert {
    condition     = aws_iam_role.auto_mode_node[0].name == "unit-auto-only-auto-node-role"
    error_message = "The default Auto Mode node role name must be predictable."
  }

  assert {
    condition     = output.auto_mode_enabled == true && output.auto_mode_node_iam_role_name == "unit-auto-only-auto-node-role"
    error_message = "Auto Mode outputs must expose the enabled state and node role name."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.auto_mode_node), "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy")
    error_message = "The Auto Mode node role must include AmazonEKSWorkerNodeMinimalPolicy."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.auto_mode_node), "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly")
    error_message = "The Auto Mode node role must include AmazonEC2ContainerRegistryPullOnly."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2")
    error_message = "The cluster role must use AmazonEKSBlockStoragePolicyV2 for Auto Mode."
  }

  assert {
    condition     = !contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy")
    error_message = "The superseded AmazonEKSBlockStoragePolicy must not be attached for Auto Mode."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSComputePolicy")
    error_message = "The cluster role must include AmazonEKSComputePolicy for Auto Mode."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy")
    error_message = "The cluster role must include AmazonEKSLoadBalancingPolicy for Auto Mode."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy")
    error_message = "The cluster role must include AmazonEKSNetworkingPolicy for Auto Mode."
  }

  assert {
    condition     = contains(flatten([for statement in data.aws_iam_policy_document.cluster_assume_role.statement : statement.actions]), "sts:TagSession")
    error_message = "The EKS cluster role trust policy must permit sts:TagSession for Auto Mode."
  }

  assert {
    condition     = length(aws_eks_node_group.this) == 0 && length(aws_eks_addon.this) == 0
    error_message = "An Auto-only caller must be able to omit managed node groups and traditional add-ons explicitly."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Auto Mode support must keep the cluster API endpoint public by default."
  }

  assert {
    condition     = contains(aws_eks_cluster.this.vpc_config[0].public_access_cidrs, "0.0.0.0/0")
    error_message = "Auto Mode support must retain the module's default public API CIDR."
  }
}

run "auto_mode_without_builtin_node_pools" {
  command = plan

  variables {
    name = "unit-auto-custom-pools"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      node_pools = []
    }
    node_groups = {}
    addons      = {}
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == true
    error_message = "Auto Mode must remain enabled when no built-in node pools are selected."
  }

  assert {
    condition     = length(aws_eks_cluster.this.compute_config[0].node_pools) == 0
    error_message = "An empty node_pools set must disable both built-in Auto Mode node pools."
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].node_role_arn == null
    error_message = "EKS compute_config must omit node_role_arn when no built-in node pools are selected."
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 1
    error_message = "The optional Auto Mode node role must remain available for custom NodeClass manifests."
  }

  assert {
    condition     = length(aws_eks_access_entry.auto_mode_node) == 1 && aws_eks_access_entry.auto_mode_node[0].type == "EC2"
    error_message = "Without built-in node pools, the Auto Mode node role must receive an explicit EC2 access entry for custom NodeClasses."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].elastic_load_balancing[0].enabled == true && aws_eks_cluster.this.storage_config[0].block_storage[0].enabled == true
    error_message = "Disabling built-in node pools must not disable other Auto Mode capabilities."
  }
}

run "auto_mode_external_global_access_entry_can_be_suppressed" {
  command = plan

  variables {
    name = "unit-auto-external-entry"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_access_entry  = false
      create_node_iam_role = false
      node_iam_role_arn    = "arn:aws:iam::123456789012:role/external-auto-node"
      node_pools           = []
    }
    node_groups = {}
    addons      = {}

    access_entries = {
      external_auto_node = {
        principal_arn = "arn:aws:iam::123456789012:role/external-auto-node"
        type          = "EC2"
        policy_associations = {
          auto_node = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(aws_eks_access_entry.auto_mode_node) == 0 && length(aws_eks_access_policy_association.auto_mode_node) == 0
    error_message = "auto_mode.create_access_entry=false must suppress the module's global Auto Mode EC2 access resources."
  }

  assert {
    condition     = aws_eks_access_entry.this["external_auto_node"].principal_arn == "arn:aws:iam::123456789012:role/external-auto-node" && aws_eks_access_entry.this["external_auto_node"].type == "EC2"
    error_message = "Suppressing the global entry must permit the same external role to be managed through access_entries."
  }

  assert {
    condition     = aws_eks_access_policy_association.this["external_auto_node:auto_node"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
    error_message = "The caller-managed external role must retain its Auto Node policy association."
  }
}

run "auto_mode_external_global_access_entry_can_be_forced" {
  command = plan

  variables {
    name = "unit-auto-forced-entry"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_access_entry  = true
      create_node_iam_role = false
      node_iam_role_arn    = "arn:aws:iam::123456789012:role/external-auto-node"
      node_pools           = []
    }
    node_groups = {}
    addons      = {}
  }

  assert {
    condition     = length(aws_eks_access_entry.auto_mode_node) == 1 && aws_eks_access_entry.auto_mode_node[0].principal_arn == "arn:aws:iam::123456789012:role/external-auto-node" && aws_eks_access_entry.auto_mode_node[0].type == "EC2"
    error_message = "auto_mode.create_access_entry=true must create the global EC2 access entry for an external role."
  }

  assert {
    condition     = length(aws_eks_access_policy_association.auto_mode_node) == 1 && aws_eks_access_policy_association.auto_mode_node[0].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
    error_message = "A forced global entry must receive AmazonEKSAutoNodePolicy."
  }
}

run "auto_mode_supports_hybrid_compute" {
  command = plan

  variables {
    name = "unit-auto-hybrid"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      node_pools = ["system"]
    }

    node_groups = {
      workloads = {
        desired_size = 1
        min_size     = 1
        max_size     = 2
      }
    }

    addons = {
      coredns = {}
      vpc-cni = {
        before_compute = true
      }
    }
  }

  override_resource {
    target          = aws_iam_role.node
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-auto-hybrid-managed-node-role"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == true
    error_message = "Hybrid clusters must keep Auto Mode compute enabled."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.compute_config[0].node_pools) == toset(["system"])
    error_message = "Hybrid clusters must honor the selected built-in Auto Mode node pools."
  }

  assert {
    condition     = toset(keys(aws_eks_node_group.this)) == toset(["workloads"])
    error_message = "Hybrid clusters must retain caller-configured managed node groups."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.this)) == toset(["coredns"])
    error_message = "Hybrid clusters must create post-compute add-ons in the regular add-on resource."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.before_compute)) == toset(["vpc-cni"])
    error_message = "Hybrid clusters must create the VPC CNI before managed node-group compute."
  }

  assert {
    condition     = toset(keys(output.addon_arns)) == toset(["coredns", "vpc-cni"])
    error_message = "The add-on ARN output must merge before-compute and post-compute add-ons."
  }

  assert {
    condition     = aws_iam_role.node.name == "unit-auto-hybrid-node-role" && length(aws_iam_role.auto_mode_node) == 1
    error_message = "Hybrid clusters must keep separate managed-node-group and Auto Mode node IAM roles."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Hybrid Auto Mode support must keep the cluster API endpoint public by default."
  }
}

run "auto_mode_can_be_explicitly_disabled" {
  command = plan

  variables {
    name = "unit-auto-disabled"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      enabled = false
    }
    addons = {
      coredns    = {}
      kube-proxy = {}
      vpc-cni = {
        before_compute = true
      }
    }
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == false
    error_message = "Explicit disablement must send compute enabled=false to EKS."
  }

  assert {
    condition     = aws_eks_cluster.this.bootstrap_self_managed_addons == false
    error_message = "An explicitly configured Auto Mode lifecycle must keep bootstrap self-managed add-ons disabled."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "The explicit-disable transition must continue managing the API authentication required by Auto Mode."
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].node_role_arn == null && try(length(aws_eks_cluster.this.compute_config[0].node_pools), 0) == 0
    error_message = "Explicit disablement must clear Auto Mode's node role and built-in node pools."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].elastic_load_balancing[0].enabled == false
    error_message = "Explicit disablement must send load balancing enabled=false to EKS."
  }

  assert {
    condition     = aws_eks_cluster.this.storage_config[0].block_storage[0].enabled == false
    error_message = "Explicit disablement must send block storage enabled=false to EKS."
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 1
    error_message = "The explicit-disable transition must retain the Auto Mode node role until auto_mode is set back to null."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.cluster), "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2")
    error_message = "The explicit-disable transition must retain Auto Mode cluster policies until auto_mode is set back to null."
  }

  assert {
    condition     = toset(keys(aws_eks_node_group.this)) == toset(["default"])
    error_message = "Disabling Auto Mode must leave standard managed node groups available."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Disabling Auto Mode must not make the cluster endpoint private."
  }
}
