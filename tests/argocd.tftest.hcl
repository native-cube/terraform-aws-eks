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

run "argocd_disabled_by_default" {
  command = plan

  variables {
    name = "unit-argocd-disabled"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]
  }

  assert {
    condition     = length(aws_eks_capability.argocd) == 0
    error_message = "The Argo CD capability should not be created by default."
  }

  assert {
    condition     = length(aws_iam_role.argocd_capability) == 0
    error_message = "The Argo CD capability IAM role should not be created by default."
  }
}

run "argocd_capability_cluster_shape" {
  command = plan

  variables {
    name = "unit-argocd"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    argocd = {
      enabled          = true
      idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
      idc_region       = "eu-west-2"
      namespace        = "argocd"
      iam_policy_arns = [
        "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
      ]
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
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Argo CD capabilities should derive API authentication when access_config is omitted."
  }

  assert {
    condition     = length(aws_iam_role.argocd_capability) == 1
    error_message = "Argo CD capability support should create a dedicated IAM role by default."
  }

  assert {
    condition     = aws_iam_role.argocd_capability[0].name == "ArgoCDCapabilityRole-unit-argocd"
    error_message = "The Argo CD capability IAM role name should use the cluster name."
  }

  assert {
    condition     = contains(keys(aws_iam_role_policy_attachment.argocd_capability), "arn:aws:iam::aws:policy/SecretsManagerReadWrite")
    error_message = "Configured Argo CD capability managed policies should be attached to the created IAM role."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].capability_name == "argocd"
    error_message = "The Argo CD capability should use the default capability name."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].type == "ARGOCD"
    error_message = "The capability type should be ARGOCD."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].delete_propagation_policy == "RETAIN"
    error_message = "The Argo CD capability should use the supported RETAIN delete propagation policy."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].configuration[0].argo_cd[0].namespace == "argocd"
    error_message = "The Argo CD namespace should be configurable."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].configuration[0].argo_cd[0].aws_idc[0].idc_instance_arn == "arn:aws:sso:::instance/ssoins-7223a1b234567890"
    error_message = "The Argo CD capability should use the configured IAM Identity Center instance."
  }

  assert {
    condition     = contains(aws_eks_capability.argocd[0].configuration[0].argo_cd[0].network_access[0].vpce_ids, "vpce-0123456789abcdef0")
    error_message = "The Argo CD capability should support private VPC endpoint access."
  }

  assert {
    condition     = toset([for mapping in aws_eks_capability.argocd[0].configuration[0].argo_cd[0].rbac_role_mapping : mapping.role]) == toset(["ADMIN", "VIEWER"])
    error_message = "The Argo CD capability should include the configured RBAC roles."
  }
}

run "argocd_external_role" {
  command = plan

  variables {
    name = "unit-argocd-external"
    subnet_ids = [
      "subnet-0123456789abcdef0",
      "subnet-0fedcba9876543210"
    ]

    argocd = {
      enabled          = true
      create_iam_role  = false
      iam_role_arn     = "arn:aws:iam::123456789012:role/platform/ArgoCDCapabilityRole-external"
      idc_instance_arn = "arn:aws:sso:::instance/ssoins-7223a1b234567890"
    }
  }

  assert {
    condition     = length(aws_iam_role.argocd_capability) == 0
    error_message = "External Argo CD capability role mode should not create an IAM role."
  }

  assert {
    condition     = aws_eks_capability.argocd[0].role_arn == "arn:aws:iam::123456789012:role/platform/ArgoCDCapabilityRole-external"
    error_message = "External Argo CD capability role mode should use the supplied IAM role ARN."
  }
}
