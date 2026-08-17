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

run "provisioned_control_plane_cluster_shape" {
  command = plan

  variables {
    name = "unit-provisioned-control-plane"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    control_plane_scaling_config = {
      tier = "tier-2xl"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.control_plane_scaling_config[0].tier == "tier-2xl"
    error_message = "The EKS cluster should use the configured control plane scaling tier."
  }
}

run "standard_control_plane_cluster_shape" {
  command = plan

  variables {
    name = "unit-standard-control-plane"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    control_plane_scaling_config = {
      tier = "standard"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.control_plane_scaling_config[0].tier == "standard"
    error_message = "The EKS cluster should support explicitly selecting the standard control plane scaling tier."
  }
}
