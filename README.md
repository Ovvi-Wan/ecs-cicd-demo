# ECS CI/CD demo

One training repository for the AWS foundation and per-app infrastructure pipelines.

## Automation is disabled

All root workflow templates end in `.yml.disabled`. GitHub does not register them,
so merging this setup cannot start a GitHub Actions or CodeBuild runner. The old
push-triggered blank.yml has been removed. Only remove `.disabled` when ready.

## Layout

- [base/](base/README.md): standalone state-bucket, CodeBuild and network roots.
- [ecs-cicd-tutorial-infrastructure/](ecs-cicd-tutorial-infrastructure/README.md):
  apps/billing/app.tfvars, apps/orders/app.tfvars and the shared terraform/ root.
- [.github/workflows/](.github/workflows/README.md): disabled PR, post-merge and
  manual all-app workflow templates at the repository root.

The existing infrastructure folder name is retained. This checkout does not yet
contain application source, a Dockerfile, or an application build/deploy workflow.
The application Terraform root currently contains locals/outputs, not ECS resources.

## Pipelines after activation

1. terraform-pr.yml plans changed apps on PRs to main and posts output as comments.
2. terraform-plan.yml generates fresh plans after main pushes, then waits for
   separate environment approval before applying each app's saved plan.
3. terraform-manual.yml plans every app when run_all=true and uses the same approval
   gates. False is a no-op.

Changes to shared infrastructure Terraform code select ALL apps. Base-only changes
are handled separately; the app workflows do not bootstrap or deploy base modules.

## Before enabling

1. Verify or provision the base modules using an approved bootstrap execution
   environment. No workstation Terraform execution is required. See base/README.md.
2. Authorize CodeConnections for Ovvi-Wan/ecs-cicd-demo. Update the repository fields
   in base/codebuild_projects/terraform.tfvars, which still reference the old split
   repositories. Review/apply that base change separately. Keep runner project keys
   stable so existing project identities and workflow runner labels remain valid.
3. On GitHub Free, required-reviewer environment approvals work ONLY in PUBLIC
   repositories. Create billing and orders environments with Required reviewers and
   deployment branches restricted to main. Configure each new app environment before
   adding that app. Naming an environment in YAML does not configure reviewers.
4. Confirm the runner has bash, git, jq, AWS CLI, gh, GNU date and sha256sum. The
   templates install Terraform 1.16.4. CodeBuild currently has a 15-minute build
   timeout while the workflows allow 30; align these limits before longer jobs.
5. Review artifact visibility before publishing real data: saved binary plans may
   contain secrets even if plan.txt redacts them. Public tutorial artifacts must
   contain only non-sensitive example data.
6. Remove .disabled from the three workflow filenames and commit them when ready
   to allow planning runners. Leave ENABLE_DEPLOYMENTS unset for plans only.
7. Once reviewer protection is configured, set the Actions repository variable
   ENABLE_DEPLOYMENTS=true. Review the plan artifact, then use Review deployments >
   Approve and deploy for the relevant app. No apply runner waits during approval.

State keys and AWS resources are unchanged by this repository reorganization.
Generated state, plans, provider caches and credentials must stay out of Git.
The root .gitignore excludes them. Existing tracked generated files, if any, need
explicit removal from Git; ignore rules do not untrack files already committed.
