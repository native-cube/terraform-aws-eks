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
