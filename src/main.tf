locals {
  enabled = module.this.enabled
}

resource "aws_organizations_organization" "this" {
  count = local.enabled ? 1 : 0

  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = var.enabled_policy_types
  feature_set                   = var.feature_set
}
