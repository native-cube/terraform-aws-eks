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

run "rejects_invalid_control_plane_scaling_tier" {
  command = plan

  variables {
    name = "unit-invalid-control-plane-scaling-tier"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    control_plane_scaling_config = {
      tier = "tier-medium"
    }
  }

  expect_failures = [
    var.control_plane_scaling_config
  ]
}

run "rejects_invalid_kube_api_server_event_ttl" {
  command = plan

  variables {
    name = "unit-invalid-api-server-event-ttl"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    kube_api_server_config = {
      event_ttl = "5m"
    }
  }

  expect_failures = [
    var.kube_api_server_config
  ]
}

run "rejects_invalid_kube_api_server_node_port_range" {
  command = plan

  variables {
    name = "unit-invalid-api-server-node-port-range"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    kube_api_server_config = {
      service_node_port_range = {
        min_port = 32000
        max_port = 30000
      }
    }
  }

  expect_failures = [
    var.kube_api_server_config
  ]
}

run "rejects_invalid_hpa_sync_period" {
  command = plan

  variables {
    name = "unit-invalid-hpa-sync-period"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    control_plane_scaling_config = {
      tier = "tier-xl"
    }

    kube_controller_manager_config = {
      horizontal_pod_autoscaler_controller_config = {
        horizontal_pod_autoscaler_sync_period = "20s"
      }
    }
  }

  expect_failures = [
    var.kube_controller_manager_config
  ]
}

run "rejects_hpa_config_on_standard_control_plane" {
  command = plan

  variables {
    name = "unit-invalid-hpa-standard-control-plane"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    control_plane_scaling_config = {
      tier = "standard"
    }

    kube_controller_manager_config = {
      horizontal_pod_autoscaler_controller_config = {
        horizontal_pod_autoscaler_sync_period = "10s"
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_invalid_scheduler_scoring_strategy" {
  command = plan

  variables {
    name = "unit-invalid-scheduler-strategy"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    kube_scheduler_config = {
      node_resources_fit = {
        scoring_strategy = {
          type = "BalancedAllocation"
        }
      }
    }
  }

  expect_failures = [
    var.kube_scheduler_config
  ]
}

run "rejects_invalid_scheduler_resource_weight" {
  command = plan

  variables {
    name = "unit-invalid-scheduler-weight"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    kube_scheduler_config = {
      node_resources_fit = {
        scoring_strategy = {
          resources = [
            {
              name   = "cpu"
              weight = 101
            }
          ]
        }
      }
    }
  }

  expect_failures = [
    var.kube_scheduler_config
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

run "rejects_invalid_capability_type" {
  command = plan

  variables {
    name = "unit-invalid-capability-type"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      invalid = {
        type = "FLUXCD"
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_capability_external_role_without_arn" {
  command = plan

  variables {
    name = "unit-invalid-capability-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      ack = {
        type            = "ACK"
        create_iam_role = false
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_capability_unsupported_delete_policy" {
  command = plan

  variables {
    name = "unit-invalid-capability-delete-policy"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      ack = {
        type                      = "ACK"
        delete_propagation_policy = "DELETE"
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_argocd_capability_without_identity_center_instance" {
  command = plan

  variables {
    name = "unit-invalid-argocd-idc"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      argocd = {
        type   = "ARGOCD"
        argocd = {}
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_argocd_config_for_non_argocd_capability" {
  command = plan

  variables {
    name = "unit-invalid-non-argocd-config"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      ack = {
        type = "ACK"
        argocd = {
          idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
        }
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_argocd_capability_invalid_rbac_role" {
  command = plan

  variables {
    name = "unit-invalid-argocd-rbac-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      argocd = {
        type = "ARGOCD"
        argocd = {
          idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
          rbac_role_mappings = [
            {
              role = "OWNER"
              identities = [
                {
                  id   = "12345678-1234-1234-1234-123456789012"
                  type = "SSO_GROUP"
                }
              ]
            }
          ]
        }
      }
    }
  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_argocd_capability_invalid_identity_type" {
  command = plan

  variables {
    name = "unit-invalid-argocd-identity-type"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      argocd = {
        type = "ARGOCD"
        argocd = {
          idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
          rbac_role_mappings = [
            {
              role = "ADMIN"
              identities = [
                {
                  id   = "12345678-1234-1234-1234-123456789012"
                  type = "IAM_ROLE"
                }
              ]
            }
          ]
        }
      }
    }

  }

  expect_failures = [
    var.capabilities
  ]
}

run "rejects_capability_with_config_map_authentication" {
  command = plan

  variables {
    name = "unit-invalid-capability-auth"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_config = {
      authentication_mode = "CONFIG_MAP"
    }

    capabilities = {
      ack = {
        type = "ACK"
      }
    }
  }

  expect_failures = [
    aws_eks_capability.this
  ]
}
