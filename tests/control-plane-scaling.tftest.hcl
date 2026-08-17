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
            {
              name   = "cpu"
              weight = 2
            },
            {
              name   = "memory"
              weight = 1
            }
          ]
        }
      }
    }
  }

  assert {
    condition     = aws_eks_cluster.this.control_plane_scaling_config[0].tier == "tier-2xl"
    error_message = "The EKS cluster should use the configured control plane scaling tier."
  }

  assert {
    condition     = aws_eks_cluster.this.kube_api_server_config[0].event_ttl == "30m"
    error_message = "The Kubernetes API server should use the configured event TTL."
  }

  assert {
    condition     = aws_eks_cluster.this.kube_api_server_config[0].service_node_port_range[0].min_port == 30000
    error_message = "The Kubernetes API server should use the configured minimum NodePort."
  }

  assert {
    condition     = aws_eks_cluster.this.kube_api_server_config[0].service_node_port_range[0].max_port == 32767
    error_message = "The Kubernetes API server should use the configured maximum NodePort."
  }

  assert {
    condition     = aws_eks_cluster.this.kube_controller_manager_config[0].horizontal_pod_autoscaler_controller_config[0].horizontal_pod_autoscaler_sync_period == "10s"
    error_message = "The Kubernetes controller manager should use the configured HPA sync period."
  }

  assert {
    condition     = aws_eks_cluster.this.kube_scheduler_config[0].node_resources_fit[0].scoring_strategy[0].type == "MostAllocated"
    error_message = "The Kubernetes scheduler should use the configured NodeResourcesFit scoring strategy."
  }

  assert {
    condition     = { for resource in aws_eks_cluster.this.kube_scheduler_config[0].node_resources_fit[0].scoring_strategy[0].resource : resource.name => resource.weight } == { cpu = 2, memory = 1 }
    error_message = "The Kubernetes scheduler should use the configured scoring resource weights."
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
