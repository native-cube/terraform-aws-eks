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

run "rejects_auto_mode_external_role_without_arn" {
  command = plan

  variables {
    name = "unit-invalid-auto-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_node_iam_role = false
    }
  }

  expect_failures = [
    var.auto_mode
  ]
}

run "rejects_forced_auto_mode_access_entry_with_builtin_node_pools" {
  command = plan

  variables {
    name = "unit-invalid-auto-entry-builtins"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_access_entry = true
    }
  }

  expect_failures = [
    var.auto_mode
  ]
}

run "rejects_forced_auto_mode_access_entry_without_role" {
  command = plan

  variables {
    name = "unit-invalid-auto-entry-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      create_access_entry  = true
      create_node_iam_role = false
      node_pools           = []
    }
  }

  expect_failures = [
    var.auto_mode
  ]
}

run "rejects_invalid_auto_mode_node_pool" {
  command = plan

  variables {
    name = "unit-invalid-auto-pool"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      node_pools = ["gpu"]
    }
  }

  expect_failures = [
    var.auto_mode
  ]
}

run "rejects_invalid_auto_mode_node_role_name" {
  command = plan

  variables {
    name = "unit-invalid-auto-role-name"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      node_iam_role_name = "role name with spaces"
    }
  }

  expect_failures = [
    var.auto_mode
  ]
}

run "rejects_auto_mode_with_config_map_authentication" {
  command = plan

  variables {
    name = "unit-invalid-auto-auth"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {}
    access_config = {
      authentication_mode = "CONFIG_MAP"
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_auto_mode_manifests_while_disabled" {
  command = plan

  variables {
    name = "unit-invalid-disabled-manifests"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {
      enabled = false
    }
    auto_mode_node_pools = {
      custom = {
        spec = {}
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_auto_mode_with_bootstrap_self_managed_addons" {
  command = plan

  variables {
    name = "unit-invalid-auto-bootstrap-addons"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode                     = {}
    bootstrap_self_managed_addons = true
    node_groups                   = {}
    addons                        = {}
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_invalid_generic_access_entry_type" {
  command = plan

  variables {
    name = "unit-invalid-access-entry-type"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_entries = {
      invalid = {
        principal_arn = "arn:aws:iam::123456789012:role/invalid"
        type          = "ROOT"
      }
    }
  }

  expect_failures = [
    var.access_entries
  ]
}

run "rejects_kubernetes_identity_fields_on_nonstandard_access_entry" {
  command = plan

  variables {
    name = "unit-invalid-node-access-fields"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_entries = {
      node = {
        kubernetes_groups = ["system:nodes"]
        principal_arn     = "arn:aws:iam::123456789012:role/worker-node"
        type              = "EC2_LINUX"
        user_name         = "system:node:custom"
      }
    }
  }

  expect_failures = [
    var.access_entries
  ]
}

run "rejects_invalid_generic_access_scope" {
  command = plan

  variables {
    name = "unit-invalid-access-scope"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_entries = {
      platform_admin = {
        principal_arn = "arn:aws:iam::123456789012:role/platform-admin"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "invalid"
            }
          }
        }
      }
    }
  }

  expect_failures = [
    var.access_entries
  ]
}

run "rejects_access_entries_with_config_map_authentication" {
  command = plan

  variables {
    name = "unit-invalid-access-auth"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_config = {
      authentication_mode = "CONFIG_MAP"
    }

    access_entries = {
      platform_admin = {
        principal_arn = "arn:aws:iam::123456789012:role/platform-admin"
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_access_entry_for_managed_node_group_role" {
  command = plan

  variables {
    name = "unit-invalid-managed-node-role-entry"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_config = {
      authentication_mode = "API"
    }

    access_entries = {
      duplicate_node = {
        principal_arn = "arn:aws:iam::123456789012:role/mock-eks-role"
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_hybrid_vpc_cni_after_compute" {
  command = plan

  variables {
    name = "unit-invalid-hybrid-cni-order"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode = {}
    node_groups = {
      workloads = {}
    }
    addons = {
      vpc-cni = {}
    }
  }

  override_resource {
    target          = aws_iam_role.node
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-invalid-hybrid-cni-managed-node-role"
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_pod_identity_external_role_without_arn" {
  command = plan

  variables {
    name = "unit-invalid-pod-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    pod_identity_associations = {
      web = {
        create_iam_role = false
        namespace       = "apps"
        service_account = "web"
      }
    }
  }

  expect_failures = [
    var.pod_identity_associations
  ]
}

run "rejects_invalid_pod_identity_namespace" {
  command = plan

  variables {
    name = "unit-invalid-pod-namespace"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    pod_identity_associations = {
      web = {
        namespace       = "Invalid_Namespace"
        service_account = "web"
      }
    }
  }

  expect_failures = [
    var.pod_identity_associations
  ]
}

run "rejects_invalid_auto_mode_node_class_name" {
  command = plan

  variables {
    name = "unit-invalid-node-class-name"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode_node_classes = {
      default = {
        spec = {}
      }
    }
  }

  expect_failures = [
    var.auto_mode_node_classes
  ]
}

run "deduplicates_auto_mode_node_class_role_entries" {
  command = plan

  variables {
    name = "unit-duplicate-node-class-role"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode   = {}
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      first = {
        access_entry_key = "shared-role"
        node_role_arn    = "arn:aws:iam::123456789012:role/SharedAutoNodeRole"
        spec = {
          role = "SharedAutoNodeRole"
        }
      }
      second = {
        access_entry_key = "shared-role"
        node_role_arn    = "arn:aws:iam::123456789012:role/SharedAutoNodeRole"
        spec = {
          role = "SharedAutoNodeRole"
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_eks_access_entry.auto_mode_node_class) == 1 &&
      aws_eks_access_entry.auto_mode_node_class["shared-role"].principal_arn == "arn:aws:iam::123456789012:role/SharedAutoNodeRole"
    )
    error_message = "NodeClasses sharing a role and access_entry_key must receive one access entry under that stable key."
  }

  assert {
    condition = (
      contains(keys(aws_eks_access_policy_association.auto_mode_node_class), "shared-role") &&
      contains(keys(output.auto_mode_node_class_access_entry_arns), "shared-role")
    )
    error_message = "The shared stable key must propagate to the policy association and access-entry output."
  }
}

run "rejects_shared_node_class_access_key_with_different_roles" {
  command = plan

  variables {
    name = "unit-conflicting-node-class-access-key"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode   = {}
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      first = {
        access_entry_key = "shared-key"
        node_role_arn    = "arn:aws:iam::123456789012:role/FirstAutoNodeRole"
        spec = {
          role = "FirstAutoNodeRole"
        }
      }
      second = {
        access_entry_key = "shared-key"
        node_role_arn    = "arn:aws:iam::123456789012:role/SecondAutoNodeRole"
        spec = {
          role = "SecondAutoNodeRole"
        }
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "rejects_explicit_node_class_access_entry_without_arn" {
  command = plan

  variables {
    name = "unit-node-class-entry-without-arn"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode   = {}
    node_groups = {}
    addons      = {}

    auto_mode_node_classes = {
      custom = {
        create_access_entry = true
        spec = {
          role = "CustomAutoNodeRole"
        }
      }
    }
  }

  expect_failures = [
    var.auto_mode_node_classes
  ]
}

run "rejects_invalid_auto_mode_node_pool_name" {
  command = plan

  variables {
    name = "unit-invalid-node-pool-name"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode_node_pools = {
      "Invalid_Pool" = {
        spec = {}
      }
    }
  }

  expect_failures = [
    var.auto_mode_node_pools
  ]
}

run "rejects_invalid_auto_mode_storage_class_name" {
  command = plan

  variables {
    name = "unit-invalid-storage-class-name"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode_storage_classes = {
      ".invalid" = {}
    }
  }

  expect_failures = [
    var.auto_mode_storage_classes
  ]
}

run "rejects_invalid_auto_mode_service_name" {
  command = plan

  variables {
    name = "unit-invalid-service-name"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    auto_mode_load_balancer_services = {
      "Invalid_Service" = {
        ports = [
          {
            port = 80
          }
        ]
        selector = {
          app = "web"
        }
      }
    }
  }

  expect_failures = [
    var.auto_mode_load_balancer_services
  ]
}

run "rejects_invalid_ip_family" {
  command = plan

  variables {
    name = "unit-invalid-ip-family-v2"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    ip_family = "dualstack"
  }

  expect_failures = [
    var.ip_family
  ]
}

run "rejects_invalid_upgrade_policy" {
  command = plan

  variables {
    name = "unit-invalid-upgrade-policy"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    upgrade_policy_support_type = "PREMIUM"
  }

  expect_failures = [
    var.upgrade_policy_support_type
  ]
}
