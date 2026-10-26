# Disabled workflow templates

These .yml.disabled templates are not active GitHub workflows. There are no active
.yml or .yaml workflow files here. Follow the [root setup](../../README.md) before
removing the suffix. Native required-reviewer approvals are public-repository-only
on GitHub Free. Configure billing/orders environment reviewers before enabling apply.

The PR workflow previews changes. The main and manual workflows generate saved
plans and require a separate approval per app before apply. Shared Terraform changes
select all apps. Base modules are not deployed by these workflows.
