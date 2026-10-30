# GitHub workflow templates

All three templates are disabled until their .disabled suffix is removed.
Follow [root setup](../../README.md) before activation. Runner identities remain
codebuild-ecs-cicd-tutorial-infrastructure even though paths now use
terraform-infrastructure/.

- terraform-pr.yml.disabled: preview changed apps and comment on trusted PRs.
- terraform-plan.yml.disabled: plan apps affected by a main push, then apply each
  saved plan only after the existing environment approval gate.
- terraform-manual.yml.disabled: run_all=true selects all deployable apps; false is a no-op.

app-example is documentation-only: excluded from path triggers and from every
matrix discovery mode. Target validation also rejects it. Policy changes under
apps/<app>/policies select that real app. Shared terraform changes select every
real app. A deleted app is an error requiring deliberate decommissioning.

These workflows only plan/apply infrastructure. They do not publish application
task-definition artifacts, create SSM parameters, or build/deploy application images.
Application delivery will be implemented in a separate pipeline.

Keep existing reviewer/environment and ENABLE_DEPLOYMENTS controls. Workflows
continue to skip applies for private repositories under the existing tutorial
approval assumptions. GitHub environment protection must be configured in Settings;
YAML alone does not add required reviewers. No workflow has been enabled here.
