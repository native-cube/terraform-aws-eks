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

run "karpenter_disabled_by_default" {
  command = plan

  variables {
    name = "unit-karpenter-disabled"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]
  }

  assert {
    condition     = length(aws_iam_role.karpenter_node) == 0
    error_message = "The Karpenter node IAM role should not be created by default."
  }

  assert {
    condition     = length(aws_eks_access_entry.karpenter_node) == 0
    error_message = "The Karpenter node access entry should not be created by default."
  }

  assert {
    condition     = length(aws_ec2_tag.karpenter_cluster_security_group) == 0
    error_message = "The EKS-created cluster security group should not be tagged for Karpenter by default."
  }

  assert {
    condition     = length(keys(aws_ec2_tag.karpenter_subnets)) == 0
    error_message = "Subnets should not be tagged for Karpenter by default."
  }
}

run "karpenter_ready_cluster_shape" {
  command = plan

  variables {
    name = "unit-karpenter"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    karpenter = {
      enabled = true
    }
  }

  override_resource {
    target          = aws_iam_role.node
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-karpenter-managed-node-role"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Karpenter access entries should derive API authentication when access_config is omitted."
  }

  assert {
    condition     = length(aws_iam_role.karpenter_node) == 1
    error_message = "Karpenter readiness should create a dedicated node IAM role by default."
  }

  assert {
    condition     = aws_iam_role.karpenter_node[0].name == "KarpenterNodeRole-unit-karpenter"
    error_message = "The Karpenter node IAM role name should follow the documented Karpenter convention."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.karpenter_node), "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore")
    error_message = "The Karpenter node IAM role should include the SSM managed instance core policy."
  }

  assert {
    condition     = length(aws_eks_access_entry.karpenter_node) == 1
    error_message = "Karpenter readiness should authorize the node IAM role with an EKS access entry."
  }

  assert {
    condition     = aws_eks_access_entry.karpenter_node[0].type == "EC2_LINUX"
    error_message = "The Karpenter node access entry should use the EC2_LINUX type."
  }

  assert {
    condition     = aws_ec2_tag.karpenter_cluster_security_group[0].key == "karpenter.sh/discovery"
    error_message = "The EKS-created cluster security group should get the Karpenter discovery tag key."
  }

  assert {
    condition     = aws_ec2_tag.karpenter_cluster_security_group[0].value == "unit-karpenter"
    error_message = "The EKS-created cluster security group should get the cluster name as the Karpenter discovery tag value."
  }

  assert {
    condition     = toset(keys(aws_ec2_tag.karpenter_subnets)) == toset(["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"])
    error_message = "Karpenter readiness should tag the selected subnets for discovery."
  }
}

run "karpenter_external_role_and_tag_switches" {
  command = plan

  variables {
    name = "unit-karpenter-external"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    karpenter = {
      enabled                    = true
      create_node_iam_role       = false
      node_iam_role_arn          = "arn:aws:iam::123456789012:role/platform/KarpenterNodeRole-external"
      tag_cluster_security_group = false
      tag_subnets                = false
    }
  }

  assert {
    condition     = length(aws_iam_role.karpenter_node) == 0
    error_message = "External Karpenter node role mode should not create a node IAM role."
  }

  assert {
    condition     = aws_eks_access_entry.karpenter_node[0].principal_arn == "arn:aws:iam::123456789012:role/platform/KarpenterNodeRole-external"
    error_message = "External Karpenter node role mode should authorize the supplied role ARN."
  }

  assert {
    condition     = length(aws_ec2_tag.karpenter_cluster_security_group) == 0
    error_message = "The cluster security group discovery tag should be optional."
  }

  assert {
    condition     = length(keys(aws_ec2_tag.karpenter_subnets)) == 0
    error_message = "Subnet discovery tags should be optional."
  }
}
