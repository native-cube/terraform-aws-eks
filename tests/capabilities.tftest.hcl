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

run "capabilities_disabled_by_default" {
  command = plan

  variables {
    name = "unit-capabilities-disabled"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]
  }

  assert {
    condition     = length(aws_eks_capability.this) == 0
    error_message = "No EKS capabilities should be created by default."
  }

  assert {
    condition     = length(aws_iam_role.eks_capability) == 0
    error_message = "No capability IAM roles should be created by default."
  }
}

run "capabilities_cluster_shape" {
  command = plan

  variables {
    name = "unit-capabilities"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      argocd = {
        type            = "ARGOCD"
        capability_name = "argocd"
        argocd = {
          idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
          idc_region       = "eu-west-2"
          namespace        = "argocd"
          network_access_vpce_ids = [
            "vpce-0123456789abcdef0"
          ]
          rbac_role_mappings = [
            {
              role = "ADMIN"
              identities = [
                {
                  id   = "12345678-1234-1234-1234-123456789012"
                  type = "SSO_GROUP"
                }
              ]
            },
            {
              role = "VIEWER"
              identities = [
                {
                  id   = "87654321-4321-4321-4321-210987654321"
                  type = "SSO_USER"
                }
              ]
            }
          ]
        }
        iam_policy_arns = [
          "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
        ]
        iam_policy_arn_map = {
          read_only = "arn:aws:iam::aws:policy/ReadOnlyAccess"
        }
      }

      ack = {
        type = "ACK"
      }

      kro = {
        type            = "KRO"
        create_iam_role = false
        iam_role_arn    = "arn:aws:iam::123456789012:role/platform/KROCapabilityRole-external"
      }
    }
  }

  override_resource {
    target          = aws_iam_role.node
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-capabilities-managed-node-role"
    }
  }

  override_resource {
    target          = aws_iam_role.eks_capability["argocd"]
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-capabilities-argocd-role"
    }
  }

  override_resource {
    target          = aws_iam_role.eks_capability["ack"]
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:role/unit-capabilities-ack-role"
    }
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "EKS capabilities should derive API authentication when access_config is omitted."
  }

  assert {
    condition     = toset(keys(aws_eks_capability.this)) == toset(["ack", "argocd", "kro"])
    error_message = "The module should create each configured EKS capability."
  }

  assert {
    condition     = aws_eks_capability.this["argocd"].type == "ARGOCD"
    error_message = "The Argo CD capability type should be ARGOCD."
  }

  assert {
    condition     = aws_eks_capability.this["ack"].type == "ACK"
    error_message = "The ACK capability type should be ACK."
  }

  assert {
    condition     = aws_eks_capability.this["kro"].type == "KRO"
    error_message = "The KRO capability type should be KRO."
  }

  assert {
    condition     = aws_eks_capability.this["ack"].capability_name == "ack"
    error_message = "Capability names should default to the map key."
  }

  assert {
    condition     = aws_eks_capability.this["argocd"].delete_propagation_policy == "RETAIN"
    error_message = "Capabilities should use the supported RETAIN delete propagation policy by default."
  }

  assert {
    condition     = aws_eks_capability.this["argocd"].configuration[0].argo_cd[0].namespace == "argocd"
    error_message = "The Argo CD namespace should be configurable."
  }

  assert {
    condition     = aws_eks_capability.this["argocd"].configuration[0].argo_cd[0].aws_idc[0].idc_instance_arn == "arn:aws:sso:::instance/ssoins-7223a1b234567890"
    error_message = "The Argo CD capability should use the configured IAM Identity Center instance."
  }

  assert {
    condition     = contains(aws_eks_capability.this["argocd"].configuration[0].argo_cd[0].network_access[0].vpce_ids, "vpce-0123456789abcdef0")
    error_message = "The Argo CD capability should support private VPC endpoint access."
  }

  assert {
    condition     = toset([for mapping in aws_eks_capability.this["argocd"].configuration[0].argo_cd[0].rbac_role_mapping : mapping.role]) == toset(["ADMIN", "VIEWER"])
    error_message = "The Argo CD capability should include the configured RBAC roles."
  }

  assert {
    condition     = toset(keys(aws_iam_role.eks_capability)) == toset(["ack", "argocd"])
    error_message = "The module should create IAM roles only for capabilities with create_iam_role enabled."
  }

  assert {
    condition     = aws_iam_role.eks_capability["argocd"].name == "ARGOCDCapabilityRole-unit-capabilities-argocd"
    error_message = "Default capability IAM role names should include type, cluster name, and capability key."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.eks_capability), "argocd:arn:aws:iam::aws:policy/SecretsManagerReadWrite")
    error_message = "Configured capability policy sets should remain supported."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.eks_capability["argocd:key:read_only"].policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "Capability policy maps should create attachments with stable capability and policy keys."
  }

  assert {
    condition     = aws_eks_capability.this["kro"].role_arn == "arn:aws:iam::123456789012:role/platform/KROCapabilityRole-external"
    error_message = "External capability role mode should use the supplied IAM role ARN."
  }

  assert {
    condition     = output.capability_iam_role_names["kro"] == "KROCapabilityRole-external"
    error_message = "Capability outputs should derive an external role name from the final ARN path segment."
  }
}

run "rejects_capability_role_reused_by_generic_access_entry" {
  command = plan

  variables {
    name = "unit-capability-access-collision"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    access_entries = {
      platform_admin = {
        principal_arn = "arn:aws:iam::123456789012:role/shared-capability-access-role"
      }
    }

    capabilities = {
      ack = {
        type            = "ACK"
        create_iam_role = false
        iam_role_arn    = "arn:aws:iam::123456789012:role/shared-capability-access-role"
      }
    }
  }

  expect_failures = [
    aws_eks_cluster.this
  ]
}

run "allows_capabilities_to_share_external_role" {
  command = plan

  variables {
    name = "unit-capability-role-collision"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    capabilities = {
      ack = {
        type            = "ACK"
        create_iam_role = false
        iam_role_arn    = "arn:aws:iam::123456789012:role/shared-capability-role"
      }

      kro = {
        type            = "KRO"
        create_iam_role = false
        iam_role_arn    = "arn:aws:iam::123456789012:role/shared-capability-role"
      }
    }
  }

  assert {
    condition = (
      aws_eks_capability.this["ack"].role_arn == "arn:aws:iam::123456789012:role/shared-capability-role" &&
      aws_eks_capability.this["kro"].role_arn == "arn:aws:iam::123456789012:role/shared-capability-role"
    )
    error_message = "EKS capabilities must be able to share an external capability role while EKS manages the shared access entry."
  }
}
