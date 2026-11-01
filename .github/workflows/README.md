# GitHub workflows

The PR and deploy workflows are enabled in source and take effect after pushing.
The manual workflow remains disabled. Follow [root setup](../../README.md).
Before enabling apply, configure an environment named for each selected app with
Ovvi-Wan as required reviewer and main-only deployment branches, and review the plan.
Runner identities remain
codebuild-ecs-cicd-tutorial-infrastructure even though paths now use
terraform-infrastructure/.

- terraform-pr.yml: preview changed apps and comment on same-repository PRs targeting main.
- terraform-deploy.yml: plan apps affected by a main push, then apply each
  saved plan only after the existing environment approval gate.
- terraform-manual.yml.disabled: run_all=true selects all deployable apps; false is a no-op.

Every job in the enabled workflows requires the repository to be
Ovvi-Wan/ecs-cicd-demo and both the original actor and rerun actor to be Ovvi-Wan.
The PR workflow also requires an owner-authored, same-repository PR; forks and
Dependabot are excluded because the CodeBuild runner has AWS credentials.
These checks skip unauthorized jobs; they do not prevent someone from opening a PR.
App-folder change detection is unchanged, and deployment still requires its
existing environment approval and ENABLE_DEPLOYMENTS controls.
The CodeBuild ACTOR_ACCOUNT_ID filter is a separate AWS-side restriction: with
the current filter, only actor 119911576 can start runners. Changing paths and
restricting actors are independent controls.

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
YAML alone does not add required reviewers. Leave ENABLE_DEPLOYMENTS unset until
the required reviewers are configured; planning still runs while apply is disabled.
