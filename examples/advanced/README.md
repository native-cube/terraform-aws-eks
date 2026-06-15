# Advanced Example

More complete example for teams that want to tune the cluster while still supplying their own networking.

This example shows:

- Restricted public Kubernetes API access.
- Full control-plane logging with configurable retention.
- Separate on-demand and spot managed node groups.
- Optional node-group subnet overrides.
- Separate module resource prefix and EKS cluster name through `name` and `cluster_name`.
- VPC CNI prefix delegation configuration.
- Additional EKS add-ons for identity, storage snapshots, node health, metrics, certificates, Prometheus exporters, and log forwarding.
- Optional IAM-backed add-ons for EBS CSI, EFS CSI, CloudWatch Observability, and ExternalDNS when their service-account role ARNs are supplied.

Provide real subnet IDs and replace the placeholder public access CIDR before applying:

```bash
terraform init
terraform plan \
  -var='control_plane_subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]' \
  -var='public_access_cidrs=["198.51.100.10/32"]'
```

By default, this example installs add-ons that do not require a dedicated IAM role:

- `coredns`
- `kube-proxy`
- `vpc-cni`
- `cert-manager`
- `eks-node-monitoring-agent`
- `eks-pod-identity-agent`
- `fluent-bit`
- `kube-state-metrics`
- `metrics-server`
- `prometheus-node-exporter`
- `snapshot-controller`

Pass the corresponding role ARN variables to also install IAM-backed add-ons:

- `ebs_csi_driver_service_account_role_arn` installs `aws-ebs-csi-driver`.
- `efs_csi_driver_service_account_role_arn` installs `aws-efs-csi-driver`.
- `cloudwatch_observability_service_account_role_arn` installs `amazon-cloudwatch-observability`.
- `external_dns_service_account_role_arn` installs `external-dns`.
