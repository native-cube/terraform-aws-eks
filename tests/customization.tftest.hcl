mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"eks.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/mock-eks-role"
      name = "mock-eks-role"
    }
  }
}

run "custom_cluster_shape" {
  command = plan

  variables {
    name               = "unit-custom-prefix"
    cluster_name       = "unit-custom"
    kubernetes_version = "1.30"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    endpoint_private_access = true
    endpoint_public_access  = false
    public_access_cidrs     = ["203.0.113.10/32"]
    cluster_security_group_ids = [
      "sg-0123456789abcdef0"
    ]

    access_config = {
      authentication_mode                         = "API_AND_CONFIG_MAP"
      bootstrap_cluster_creator_admin_permissions = true
    }

    deletion_protection = true

    enabled_cluster_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    cloudwatch_log_retention_days   = 90
    cloudwatch_log_group_kms_key_id = "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000001"
    cluster_encryption_config = {
      provider_key_arn = "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000002"
      resources        = ["secrets"]
    }
    service_ipv4_cidr = "172.20.0.0/16"

    node_groups = {
      system = {
        capacity_type          = "ON_DEMAND"
        desired_size           = 2
        disk_size              = 50
        instance_types         = ["m7i.large"]
        labels                 = { workload = "system" }
        max_size               = 4
        min_size               = 2
        update_max_unavailable = 1
      }

      spot = {
        capacity_type = "SPOT"
        desired_size  = 1
        disk_size     = 50
        instance_types = [
          "m7i.large",
          "m7a.large"
        ]
        labels = {
          capacity = "spot"
          workload = "application"
        }
        max_size               = 6
        min_size               = 0
        update_max_unavailable = 1
        node_repair_config = {
          enabled                            = true
          max_parallel_nodes_repaired_count  = 1
          max_unhealthy_node_threshold_count = 2
          overrides = [
            {
              min_repair_wait_time_mins = 30
              node_monitoring_condition = "Ready"
              node_unhealthy_reason     = "KubeletNotReady"
              repair_action             = "Replace"
            }
          ]
        }
        taints = [
          {
            effect = "NO_SCHEDULE"
            key    = "capacity"
            value  = "spot"
          }
        ]
      }
    }

    addons = {
      coredns    = {}
      kube-proxy = {}
      vpc-cni = {
        configuration_values = jsonencode({
          env = {
            ENABLE_PREFIX_DELEGATION = "true"
            WARM_PREFIX_TARGET       = "1"
          }
        })
      }
      eks-pod-identity-agent = {}
      aws-ebs-csi-driver = {
        pod_identity_associations = [
          {
            role_arn        = "arn:aws:iam::123456789012:role/ebs-csi-driver"
            service_account = "ebs-csi-controller-sa"
          }
        ]
      }
    }

    tags = {
      Environment = "test"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.name == "unit-custom"
    error_message = "The EKS cluster should use cluster_name when it is set."
  }

  assert {
    condition     = aws_cloudwatch_log_group.cluster[0].name == "/aws/eks/unit-custom/cluster"
    error_message = "The control plane log group should use the actual EKS cluster name."
  }

  assert {
    condition     = aws_eks_node_group.this["spot"].node_group_name == "unit-custom-prefix-spot"
    error_message = "Managed node group names should continue to use name as the resource prefix."
  }

  assert {
    condition     = aws_eks_cluster.this.version == "1.30"
    error_message = "The cluster should use the requested Kubernetes version."
  }

  assert {
    condition     = aws_eks_cluster.this.deletion_protection == true
    error_message = "Cluster deletion protection should be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API_AND_CONFIG_MAP"
    error_message = "Cluster access authentication mode should be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions == true
    error_message = "Cluster creator admin bootstrap permissions should be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == false
    error_message = "Public endpoint access should be configurable."
  }

  assert {
    condition     = contains(aws_eks_cluster.this.vpc_config[0].security_group_ids, "sg-0123456789abcdef0")
    error_message = "Additional cluster security groups should be configurable."
  }

  assert {
    condition     = contains(aws_eks_cluster.this.vpc_config[0].public_access_cidrs, "203.0.113.10/32")
    error_message = "The cluster should use the configured public API CIDR."
  }

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr == "172.20.0.0/16"
    error_message = "The cluster should use the configured service IPv4 CIDR."
  }

  assert {
    condition     = contains(aws_eks_cluster.this.encryption_config[0].resources, "secrets")
    error_message = "Cluster secrets encryption resources should be configurable."
  }

  assert {
    condition     = aws_eks_cluster.this.encryption_config[0].provider[0].key_arn == "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000002"
    error_message = "Cluster secrets encryption should use the configured KMS key."
  }

  assert {
    condition     = aws_cloudwatch_log_group.cluster[0].retention_in_days == 90
    error_message = "Control plane log retention should be configurable."
  }

  assert {
    condition     = aws_cloudwatch_log_group.cluster[0].kms_key_id == "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000001"
    error_message = "Control plane log group KMS encryption should be configurable."
  }

  assert {
    condition     = toset(keys(aws_eks_node_group.this)) == toset(["system", "spot"])
    error_message = "The module should create the configured managed node groups."
  }

  assert {
    condition     = aws_eks_node_group.this["spot"].capacity_type == "SPOT"
    error_message = "The spot node group should use SPOT capacity."
  }

  assert {
    condition     = one(aws_eks_node_group.this["spot"].taint).effect == "NO_SCHEDULE"
    error_message = "The spot node group should include the configured taint."
  }

  assert {
    condition     = aws_eks_node_group.this["spot"].node_repair_config[0].enabled == true
    error_message = "Node repair config should be configurable for managed node groups."
  }

  assert {
    condition     = one(aws_eks_node_group.this["spot"].node_repair_config[0].node_repair_config_overrides).repair_action == "Replace"
    error_message = "Node repair overrides should be configurable for managed node groups."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.this)) == toset(["aws-ebs-csi-driver", "coredns", "eks-pod-identity-agent", "kube-proxy", "vpc-cni"])
    error_message = "The module should create the configured add-on set."
  }

  assert {
    condition     = one(aws_eks_addon.this["aws-ebs-csi-driver"].pod_identity_association).service_account == "ebs-csi-controller-sa"
    error_message = "Add-ons should support EKS pod identity associations."
  }
}
