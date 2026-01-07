# Migration Guide: Monolithic `account` to Single-Resource `aws-organization`

This document outlines the migration from the monolithic `account` component to the new single-resource `aws-organization` component.

## Overview

The previous `account` component created all AWS Organizations resources (organization, OUs, accounts, SCPs) in a single Terraform state. The new `aws-organization` component follows the single-resource pattern - it manages only the AWS Organization itself.

### Why Migrate?

| Aspect | Old `account` Component | New `aws-organization` Component |
|--------|-------------------------|----------------------------------|
| **Scope** | Entire organization hierarchy | Single organization resource |
| **State** | All resources in one state | Independent state |
| **Lifecycle** | Changes affect all resources | Changes isolated to organization |
| **Risk** | High blast radius | Minimal blast radius |

### New Component Suite

The monolithic `account` component is replaced by these single-resource components:

| Component | Purpose |
|-----------|---------|
| `aws-organization` | Creates/imports the AWS Organization (this component) |
| `aws-organizational-unit` | Creates/imports a single OU |
| `aws-account` | Creates/imports a single AWS Account |
| `aws-account-settings` | Configures account settings |
| `aws-scp` | Creates/imports Service Control Policies |

---

## Migration Steps

### Phase 1: Get Organization ID

```bash
aws organizations describe-organization --query 'Organization.Id' --output text
# Example output: o-abc123xyz
```

### Phase 2: Create Stack Configuration

```yaml
# stacks/orgs/<namespace>/core/root/global-region.yaml
components:
  terraform:
    aws-organization:
      vars:
        region: us-east-1
        aws_service_access_principals:
          - cloudtrail.amazonaws.com
          - guardduty.amazonaws.com
          - ram.amazonaws.com
          - sso.amazonaws.com
        enabled_policy_types:
          - SERVICE_CONTROL_POLICY
          - TAG_POLICY
        feature_set: ALL
        # Import existing organization
        import_resource_id: "o-abc123xyz"
```

### Phase 3: Import the Organization

```bash
atmos terraform apply aws-organization -s <namespace>-gbl-root
```

The import block will automatically import the existing organization.

### Phase 4: Remove from Old Component State

> [!CAUTION]
> Use `terraform state rm` to remove resources from state without destroying them.

```bash
# Remove organization from old state
atmos terraform state rm account -s <namespace>-gbl-root \
  'aws_organizations_organization.this[0]'
```

### Phase 5: Clean Up

After successful import, remove `import_resource_id` from the configuration:

```yaml
components:
  terraform:
    aws-organization:
      vars:
        region: us-east-1
        aws_service_access_principals:
          - cloudtrail.amazonaws.com
          # ...
        # Remove this line after import:
        # import_resource_id: "o-abc123xyz"
```

---

## Troubleshooting

### Import Block Not Working

Ensure you're using OpenTofu >= 1.7.0 (required for `for_each` in `import` blocks).

If you excluded `imports.tf` when vendoring, use manual import:

```bash
atmos terraform import aws-organization -s <namespace>-gbl-root \
  'aws_organizations_organization.this[0]' 'o-abc123xyz'
```

### Organization Already Exists Error

This means the organization is being managed in both states. Complete Phase 4 first.

---

## References

- [OpenTofu Import Blocks](https://opentofu.org/docs/language/import/)
- [AWS Organizations API](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_org.html)
