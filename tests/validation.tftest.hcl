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

run "rejects_single_subnet" {
  command = plan

  variables {
    name       = "unit-invalid-subnets"
    subnet_ids = ["subnet-0123456789abcdef0"]
  }

  expect_failures = [
    var.subnet_ids
  ]
}

run "rejects_invalid_node_group_size_bounds" {
  command = plan

  variables {
    name = "unit-invalid-node-group"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    node_groups = {
      default = {
        min_size     = 3
        desired_size = 2
        max_size     = 4
      }
    }
  }

  expect_failures = [
    var.node_groups
  ]
}

run "rejects_invalid_access_authentication_mode" {
  command = plan

  variables {
    name = "unit-invalid-access"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_config = {
      authentication_mode = "INVALID"
    }
  }

  expect_failures = [
    var.access_config
  ]
}

run "rejects_unsupported_cluster_encryption_resource" {
  command = plan

  variables {
    name = "unit-invalid-encryption"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    cluster_encryption_config = {
      provider_key_arn = "arn:aws:kms:eu-west-2:123456789012:key/00000000-0000-0000-0000-000000000002"
      resources        = ["configmaps"]
    }
  }

  expect_failures = [
    var.cluster_encryption_config
  ]
}

run "rejects_karpenter_external_role_without_arn" {
  command = plan

  variables {
    name = "unit-invalid-karpenter-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    karpenter = {
      enabled              = true
      create_node_iam_role = false
    }
  }

  expect_failures = [
    var.karpenter
  ]
}

run "rejects_karpenter_access_entry_with_config_map_authentication" {
  command = plan

  variables {
    name = "unit-invalid-karpenter-auth"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_config = {
      authentication_mode = "CONFIG_MAP"
    }

    karpenter = {
      enabled = true
    }
  }

  expect_failures = [
    aws_eks_access_entry.karpenter_node
  ]
}
