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

run "auto_mode_access_pod_identity_and_manifests" {
  command = plan

  variables {
    name = "unit-auto-integrations"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      cluster_iam_policy_arn_map = {
        custom_cluster = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
      }
      node_iam_policy_arn_map = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      node_iam_policy_arns = [
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
    }
    node_groups = {}
    addons      = {}

    access_entries = {
      platform_admin = {
        principal_arn = "arn:aws:iam::123456789012:role/platform-admin"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }

      namespace_viewer = {
        principal_arn = "arn:aws:iam::123456789012:role/namespace-viewer"
        policy_associations = {
          view = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = {
              type       = "namespace"
              namespaces = ["apps"]
            }
          }
        }
      }

      custom_compute = {
        principal_arn = "arn:aws:iam::123456789012:role/generic-ec2-node"
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

    pod_identity_associations = {
      web = {
        namespace       = "apps"
        service_account = "web"
        iam_policy_arn_map = {
          xray = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
        }
        iam_policy_arns = [
          "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        ]
      }

      external = {
        create_iam_role = false
        iam_role_arn    = "arn:aws:iam::123456789012:role/external-pod-role"
        namespace       = "apps"
        service_account = "external"
      }
    }

    auto_mode_node_classes = {
      custom = {
        node_role_arn = "arn:aws:iam::123456789012:role/CustomAutoNodeRole"
        spec = {
          role = "CustomAutoNodeRole"
          subnetSelectorTerms = [
            {
              tags = {
                Tier = "private"
              }
            }
          ]
        }
      }

    }

    auto_mode_node_pools = {
      custom = {
        spec = {
          template = {
            spec = {
              nodeClassRef = {
                group = "eks.amazonaws.com"
                kind  = "NodeClass"
                name  = "custom"
              }
              requirements = [
                {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["on-demand"]
                }
              ]
            }
          }
        }
      }
    }

    auto_mode_storage_classes = {
      "gp3-encrypted" = {
        parameters = {
          iops = "5000"
          type = "gp3"
        }
      }
    }

    auto_mode_load_balancer_services = {
      web = {
        namespace = "apps"
        selector = {
          app = "web"
        }
        ports = [
          {
            name       = "http"
            port       = 80
            protocol   = "TCP"
            targetPort = 8080
          }
        ]
      }
    }
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Auto Mode integrations must use API authentication by default."
  }

  assert {
    condition     = toset(keys(aws_eks_access_entry.this)) == toset(["custom_compute", "namespace_viewer", "platform_admin"])
    error_message = "Every configured generic access entry must be created."
  }

  assert {
    condition     = aws_eks_access_entry.this["custom_compute"].type == "EC2"
    error_message = "Generic access entries must support the EC2 type used by Auto Mode custom compute."
  }

  assert {
    condition     = aws_eks_access_policy_association.this["custom_compute:auto_node"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
    error_message = "Generic EC2 access entries must support the cluster-scoped AmazonEKSAutoNodePolicy association."
  }

  assert {
    condition     = aws_eks_access_policy_association.this["platform_admin:admin"].access_scope[0].type == "cluster"
    error_message = "Cluster-scoped access policy associations must be preserved."
  }

  assert {
    condition     = contains(aws_eks_access_policy_association.this["namespace_viewer:view"].access_scope[0].namespaces, "apps")
    error_message = "Namespace-scoped access policy associations must preserve their namespaces."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.auto_mode_node), "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy")
    error_message = "Caller-supplied Auto Mode node policy sets must remain supported."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.auto_mode_cluster_additional["custom_cluster"].policy_arn == "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    error_message = "Auto Mode cluster policy maps must use caller-supplied stable attachment keys."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.auto_mode_node_additional["ssm"].policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "Auto Mode node policy maps must use caller-supplied stable attachment keys."
  }

  assert {
    condition     = yamldecode(local.auto_mode_node_class_manifests["custom"]).kind == "NodeClass"
    error_message = "The module must render custom Auto Mode NodeClass YAML."
  }

  assert {
    condition     = yamldecode(local.auto_mode_node_class_manifests["custom"]).spec.role == "CustomAutoNodeRole"
    error_message = "A custom NodeClass must preserve its explicitly configured node role name."
  }

  assert {
    condition     = yamldecode(local.auto_mode_node_pool_manifests["custom"]).kind == "NodePool"
    error_message = "The module must render custom Auto Mode NodePool YAML."
  }

  assert {
    condition     = yamldecode(local.auto_mode_storage_class_manifests["gp3-encrypted"]).provisioner == "ebs.csi.eks.amazonaws.com"
    error_message = "The module must render EKS Auto Mode EBS StorageClass YAML."
  }

  assert {
    condition     = yamldecode(local.auto_mode_storage_class_manifests["gp3-encrypted"]).parameters.encrypted == "true"
    error_message = "Rendered Auto Mode storage classes must default to encryption."
  }

  assert {
    condition     = yamldecode(local.auto_mode_load_balancer_service_manifests["web"]).spec.loadBalancerClass == "eks.amazonaws.com/nlb"
    error_message = "The module must render EKS Auto Mode NLB Service YAML."
  }

  assert {
    condition     = toset(keys(local.auto_mode_kubernetes_manifests)) == toset(["nodeclass/custom", "nodepool/custom", "service/web", "storageclass/gp3-encrypted"])
    error_message = "The aggregate manifest map must contain every rendered Auto Mode object."
  }

  assert {
    condition     = output.auto_mode_kubernetes_manifests == local.auto_mode_kubernetes_manifests && output.auto_mode_kubernetes_manifest_yaml != ""
    error_message = "The module outputs must expose both map and multi-document forms of the rendered manifests."
  }

  assert {
    condition     = aws_eks_access_entry.auto_mode_node_class["custom"].type == "EC2" && aws_eks_access_entry.auto_mode_node_class["custom"].principal_arn == "arn:aws:iam::123456789012:role/CustomAutoNodeRole"
    error_message = "A NodeClass with a known role ARN must derive an EC2 access entry keyed by its NodeClass name."
  }

  assert {
    condition     = aws_eks_access_policy_association.auto_mode_node_class["custom"].policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
    error_message = "The derived NodeClass access entry key must also key its AmazonEKSAutoNodePolicy association."
  }

  assert {
    condition     = contains(keys(output.auto_mode_node_class_access_entry_arns), "custom")
    error_message = "The NodeClass access-entry output must use the derived stable NodeClass key."
  }

  assert {
    condition     = length(aws_eks_access_entry.auto_mode_node) == 0
    error_message = "The module must not duplicate the access entry that EKS manages for built-in Auto Mode node pools."
  }

  assert {
    condition     = toset(keys(aws_eks_pod_identity_association.this)) == toset(["external", "web"])
    error_message = "Every configured Pod Identity association must be created."
  }

  assert {
    condition     = aws_eks_pod_identity_association.this["web"].namespace == "apps" && aws_eks_pod_identity_association.this["web"].service_account == "web"
    error_message = "Pod Identity must target the configured namespace and service account."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.pod_identity), "web:arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy")
    error_message = "Pod Identity policy sets must remain supported."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.pod_identity["web:key:xray"].policy_arn == "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
    error_message = "Pod Identity policy maps must create attachments with stable association and policy keys."
  }

  assert {
    condition     = length(aws_iam_role.pod_identity) == 1
    error_message = "Pod Identity must create IAM roles only for associations that request one."
  }

  assert {
    condition     = aws_eks_pod_identity_association.this["external"].role_arn == "arn:aws:iam::123456789012:role/external-pod-role"
    error_message = "Pod Identity must support externally managed IAM roles."
  }

  assert {
    condition     = output.pod_identity_iam_role_arns["external"] == "arn:aws:iam::123456789012:role/external-pod-role"
    error_message = "Pod Identity outputs must expose external IAM role ARNs."
  }

  assert {
    condition     = output.pod_identity_iam_role_names["external"] == "external-pod-role"
    error_message = "Pod Identity outputs must derive an external role name from the final ARN path segment."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Adding Auto Mode integrations must keep the public cluster endpoint enabled."
  }
}

run "auto_mode_node_class_defaults_to_module_role" {
  command = plan

  variables {
    name = "unit-auto-node-class-default"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode   = {}
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      defaulted = {
        spec = {
          ephemeralStorage = {
            size = "60Gi"
          }
        }
      }
    }
  }

  assert {
    condition     = yamldecode(local.auto_mode_node_class_manifests["defaulted"]).spec.role == "unit-auto-node-class-default-auto-node-role"
    error_message = "A custom NodeClass must default to the module-created Auto Mode node role name."
  }

  assert {
    condition     = length(aws_eks_access_entry.auto_mode_node_class) == 0
    error_message = "Omitting create_access_entry and node_role_arn must avoid an access entry while still rendering the NodeClass with the global role."
  }
}

run "auto_mode_custom_only_without_global_node_role" {
  command = plan

  variables {
    name = "unit-auto-custom-only"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_node_iam_role = false
      node_pools           = []
    }
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      custom = {
        create_access_entry = true
        node_role_arn       = "arn:aws:iam::123456789012:role/CustomOnlyAutoNodeRole"
        spec = {
          role = "CustomOnlyAutoNodeRole"
        }
      }
    }

    auto_mode_node_pools = {
      custom = {
        spec = {
          template = {
            spec = {
              nodeClassRef = {
                group = "eks.amazonaws.com"
                kind  = "NodeClass"
                name  = "custom"
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == true && length(aws_eks_cluster.this.compute_config[0].node_pools) == 0
    error_message = "Custom-only Auto Mode must remain enabled without built-in node pools."
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].node_role_arn == null
    error_message = "Custom-only Auto Mode must omit the global node role from compute_config."
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 0 && length(aws_eks_access_entry.auto_mode_node) == 0
    error_message = "Custom-only Auto Mode must not create a global node role or its singleton access entry."
  }

  assert {
    condition     = aws_eks_access_entry.auto_mode_node_class["custom"].principal_arn == "arn:aws:iam::123456789012:role/CustomOnlyAutoNodeRole"
    error_message = "Custom-only Auto Mode must honor an explicitly requested NodeClass access entry."
  }
}

run "auto_mode_custom_only_derives_role_from_node_class_arn" {
  command = plan

  variables {
    name = "unit-auto-custom-only-derived-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_node_iam_role = false
      node_pools           = []
    }
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      custom = {
        node_role_arn = "arn:aws:iam::123456789012:role/platform/CustomOnlyDerivedRole"
        spec = {
          ephemeralStorage = {
            size = "80Gi"
          }
        }
      }
    }
  }

  assert {
    condition     = yamldecode(local.auto_mode_node_class_manifests["custom"]).spec.role == "CustomOnlyDerivedRole"
    error_message = "A custom-only NodeClass must derive spec.role from its node_role_arn when no global Auto Mode role exists."
  }

  assert {
    condition     = aws_eks_access_entry.auto_mode_node_class["custom"].principal_arn == "arn:aws:iam::123456789012:role/platform/CustomOnlyDerivedRole"
    error_message = "A custom-only NodeClass with a plan-known node_role_arn must create its EC2 access entry."
  }
}

run "auto_mode_external_role_and_cluster_options" {
  command = plan

  variables {
    name = "unit-auto-external"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_node_iam_role = false
      node_iam_role_arn    = "arn:aws:iam::123456789012:role/platform/EKSAutoNodeRole"
      node_pools           = ["system"]
    }
    node_groups = {}
    addons      = {}

    force_update_version        = true
    ip_family                   = "ipv4"
    service_ipv4_cidr           = "172.20.0.0/16"
    upgrade_policy_support_type = "STANDARD"
  }

  assert {
    condition     = length(aws_iam_role.auto_mode_node) == 0
    error_message = "External Auto Mode node role mode must not create an IAM role."
  }

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].node_role_arn == "arn:aws:iam::123456789012:role/platform/EKSAutoNodeRole"
    error_message = "External Auto Mode node role mode must pass the supplied ARN to EKS."
  }

  assert {
    condition     = output.auto_mode_node_iam_role_arn == "arn:aws:iam::123456789012:role/platform/EKSAutoNodeRole" && output.auto_mode_node_iam_role_name == "EKSAutoNodeRole"
    error_message = "Auto Mode outputs must expose the external node role ARN and derived role name."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.compute_config[0].node_pools) == toset(["system"])
    error_message = "External role mode must retain the configured built-in node pools."
  }

  assert {
    condition     = aws_eks_cluster.this.force_update_version == true
    error_message = "The cluster force-update option must be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].ip_family == "ipv4"
    error_message = "The Kubernetes service IP family must be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr == "172.20.0.0/16"
    error_message = "The Kubernetes service IPv4 CIDR must be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.upgrade_policy[0].support_type == "STANDARD"
    error_message = "The Kubernetes version support policy must be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Custom Auto Mode settings must keep the public cluster endpoint enabled by default."
  }
}
