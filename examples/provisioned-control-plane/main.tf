terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "eks" {
  source = "../.."

  name         = var.name
  cluster_name = var.cluster_name
  subnet_ids   = var.subnet_ids

  control_plane_scaling_config = {
    tier = var.control_plane_scaling_tier
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
            weight = 1
          },
          {
            name   = "memory"
            weight = 1
          }
        ]
      }
    }
  }

  node_groups = {
    system = {
      instance_types = ["m7i.large"]
      min_size       = 2
      desired_size   = 2
      max_size       = 4
    }
  }

  tags = merge(
    var.tags,
    {
      Example = "provisioned-control-plane"
    }
  )
}
