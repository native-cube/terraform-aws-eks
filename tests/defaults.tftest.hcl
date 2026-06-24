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

run "default_cluster_shape" {
  command = plan

  variables {
    name = "unit-default"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.name == "unit-default"
    error_message = "The EKS cluster name should match var.name."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access == true
    error_message = "Private endpoint access should be enabled by default."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == true
    error_message = "Public endpoint access should be enabled by default."
  }

  assert {
    condition     = contains(aws_eks_cluster.this.vpc_config[0].public_access_cidrs, "0.0.0.0/0")
    error_message = "The default public API access CIDR should be 0.0.0.0/0."
  }

  assert {
    condition     = aws_cloudwatch_log_group.cluster[0].name == "/aws/eks/unit-default/cluster"
    error_message = "The control plane log group name should follow the EKS log group convention."
  }

  assert {
    condition     = aws_cloudwatch_log_group.cluster[0].retention_in_days == 30
    error_message = "The default control plane log retention should be 30 days."
  }

  assert {
    condition     = toset(keys(aws_eks_node_group.this)) == toset(["default"])
    error_message = "The module should create the default managed node group when node_groups is omitted."
  }

  assert {
    condition     = aws_eks_node_group.this["default"].scaling_config[0].desired_size == 2
    error_message = "The default node group desired size should be 2."
  }

  assert {
    condition     = contains(aws_eks_node_group.this["default"].instance_types, "t3.medium")
    error_message = "The default node group should use t3.medium instances."
  }

  assert {
    condition     = toset(keys(aws_eks_addon.this)) == toset(["coredns", "kube-proxy", "vpc-cni"])
    error_message = "The default add-ons should be coredns, kube-proxy, and vpc-cni."
  }
}
