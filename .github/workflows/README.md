# GitHub workflows

The PR and deploy workflows are enabled in source and take effect after pushing.
The manual workflow remains disabled. Follow [root setup](../../README.md).
Before enabling apply, configure the shared terraform-apply environment with
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
shared environment approval, ENABLE_DEPLOYMENTS and TERRAFORM_APPROVAL_READY controls.
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

Keep the shared reviewer/environment and deployment-variable controls. Workflows
continue to skip applies for private repositories under the existing tutorial
approval assumptions. GitHub environment protection must be configured in Settings;
YAML alone does not add required reviewers. Leave TERRAFORM_APPROVAL_READY unset until
the shared required reviewers are configured; planning still runs while apply is disabled.

## Review and apply

After a push to main, detect-changes selects the affected apps and plan runs for
those apps. Open the workflow run's Summary to see each app's proposed Terraform
changes. The full output is also in the Terraform plan step log and plan.txt artifact;
large summaries show a truncated preview with a notice.

Use Review deployments to approve terraform-apply after reviewing every selected
app plan, or reject it to stop deployment. The shared approval releases pending
app applies together; it is not a separate approval decision for each application.
No separate Run workflow action is needed. New apps automatically use this same
environment; no per-app environment setup is required.

One-time setup in GitHub:
1. In Settings > Environments, create terraform-apply with Ovvi-Wan as a required
   reviewer and restrict deployment branches to main. Allow self-review if you
   need to approve your own pushes, and disable administrator bypass.
2. After saving those rules, set the repository Actions variable
   TERRAFORM_APPROVAL_READY=true. ENABLE_DEPLOYMENTS must also be true.

An environment declaration alone does not pause apply. The new setup switch keeps
applies skipped during migration even if ENABLE_DEPLOYMENTS was already true;
it does not inspect GitHub settings or replace required reviewers. Keep the shared
reviewer rule enabled. Cancel pending runs using the old workflow before switching.
If app environments held secrets or variables, migrate any needed values to the
shared environment or repository; per-app environments are no longer referenced.
