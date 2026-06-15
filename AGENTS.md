# Codex Instructions

These instructions apply to the whole Terraform EKS module.

## Module Scope

- Keep this as a reusable EKS module, not a full environment stack.
- Do not create VPCs, subnets, NAT gateways, route tables, or AWS provider configuration in the root module. Examples may configure providers.
- Accept existing network inputs such as `subnet_ids` and expose outputs useful for composition with other modules.
- Preserve backward compatibility for existing variables and outputs unless the user explicitly asks for a breaking change.

## Terraform Style

- Run `terraform fmt -recursive` after editing Terraform files.
- Keep root module files split by concern:
  - `versions.tf` for Terraform and provider constraints.
  - `variables.tf` for inputs and validation.
  - `locals.tf` for derived names, tags, and constants.
  - `iam.tf` for IAM roles, policies, and attachments.
  - `logs.tf` for CloudWatch log resources.
  - `main.tf` for EKS cluster, node groups, and add-ons.
  - `outputs.tf` for module outputs.
- Keep all variables and outputs documented with clear descriptions.
- Add validation blocks for inputs with constrained values or important shape requirements.
- Prefer `for_each` with stable map keys for repeatable resources. Use `count` only for simple optional singleton resources.
- Use `data.aws_partition.current.partition` for AWS-managed policy ARNs instead of hard-coding `aws`.
- Use `local.common_tags` for created AWS resources unless there is a specific reason not to.
- Avoid hard-coded AWS regions, accounts, profiles, credentials, ARNs, subnet IDs, or cluster names in the reusable module.

## EKS Practices

- Keep the control plane IAM role and managed node group IAM role separate.
- Keep IAM permissions minimal and explain any new broad permissions in the final response.
- Prefer EKS managed node groups for this simple module unless the user asks for self-managed nodes or Karpenter.
- Preserve control-plane log retention when cluster logging is enabled.
- Treat `public_access_cidrs = ["0.0.0.0/0"]` as acceptable only for simple examples; call out that production callers should restrict it.
- Do not add Kubernetes providers, Helm releases, or in-cluster resources to this module unless the user explicitly expands the scope.

## Examples And Docs

- Keep all usage examples of the module under `examples/` that consume this module from `../..`.
- Update the README when adding, removing, or changing user-facing variables, outputs, examples, or behavior.
- Do not commit real `terraform.tfvars`, state files, credentials, generated plans, or local `.terraform/` directories.

## Verification

For root module changes, run:

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test
```

For example changes, also run the same init and validate commands from the touched example directory.

Do not run `terraform apply`, `terraform destroy`, or destructive state commands unless the user explicitly asks for them and confirms the target environment.
