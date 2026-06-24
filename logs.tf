resource "aws_cloudwatch_log_group" "cluster" {
  count = length(var.enabled_cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${local.cluster_name}/cluster"
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.common_tags
}
