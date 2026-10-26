# Terraform CI/CD with per-app approval

This tutorial uses GitHub's BUILT-IN environment approvals, not a Docker-based
third-party approval action. On GitHub Free, required-reviewer environment
approvals work ONLY for PUBLIC repositories. Private repositories on GitHub Free
cannot use this approval gate. These apply jobs explicitly skip private repos.

## Monorepo paths and activation

The templates live at the repository root .github/workflows and currently end in
.yml.disabled. Read [the root setup](../README.md) before enabling them.
Detection runs in ecs-cicd-tutorial-infrastructure and uses git diff --relative.
Terraform runs in ecs-cicd-tutorial-infrastructure/terraform, so
../apps/<app>/app.tfvars still resolves correctly. Artifact paths include the
infrastructure directory prefix. No nested .github directory is needed.

## Flow

PR preview -> merge to main -> fresh parallel plans -> review deployments -> apply

- terraform-pr.yml: detect changed apps, run preview plans, and post a new PR
  comment per app using Bash and GitHub CLI. These previews never deploy.
- terraform-plan.yml: main pushes touching this folder's apps/** or terraform/** create a saved plan per app.
  After all plans succeed, each app's apply job waits for its own environment
  approval in the SAME workflow run. Rejecting one app does not cancel other apps.
- terraform-manual.yml: run_all=true on main plans every app, then uses the same
  per-app environment approvals. False selects nothing. There is no approval bypass.

The separate terraform-deploy.yml dispatch workflow has been removed. Do not keep
older automatic-apply or manual-deploy workflow files when publishing these files.

## Configure GitHub before enabling deployment

1. Use the repository-root .github/workflows templates and follow ../README.md
   to activate them. Make the repository public.
2. In Settings > Environments, create an environment for EACH app folder. For the
   current example, create billing and orders (exactly these names).
3. On EACH environment, enable Required reviewers, select the authorized reviewer
   or reviewers, and save. GitHub needs one approval from the configured list.
   Restrict deployment branches to main. Disable administrator bypass if you want
   administrators to follow the same gate. Enable Prevent self-review if a different
   person must approve; for a solo tutorial, leave it off so you can approve your run.
4. Only after those protections exist, create the Actions repository variable
   ENABLE_DEPLOYMENTS with the value true under Settings > Secrets and variables >
   Actions > Variables. Until then, workflows generate plans but skip apply jobs.
5. Before adding another app, create its environment and required reviewers too.
   Referencing an environment in YAML does NOT configure reviewers. GitHub can
   create an unprotected environment automatically if its name does not exist.

The enable variable is an explicit setup switch, not a substitute for required
reviewers. Environment protections are GitHub settings and cannot be enabled by
these workflow files alone. Changing repository visibility alone does not enable
deployment. No Docker approval container or issues: write permission is required.

## Review and approve

Open the workflow run in Actions. Download the artifact for the app you are
reviewing (plan-<app>-<run-id>-<attempt>) and read plan.txt. The archive also contains
the executable tfplan and metadata.json. After planning completes, click Review
deployments, select the appropriate app environment, then Approve and deploy.
You can approve billing while leaving orders waiting, or reject an app.

GitHub waits BEFORE assigning an approval-gated job to a runner, so no CodeBuild
apply runner remains idle during the approval wait. After approval, a fresh runner
downloads that app's saved plan from the same workflow run and attempt, verifies
its identity/checksum, checks out the same commit, and runs terraform apply tfplan.
It does not generate a replacement plan during deployment.

Plans expire after 24 hours and artifacts are retained for one day. If main has
advanced, the plan is too old, or Terraform reports stale state, generate fresh
plans and approve again. For reruns, use Re-run all jobs so planning creates new
artifacts for the new attempt; rerunning only apply cannot reuse the old attempt.
This deliberately requires renewed review rather than silently using another plan.
An unrelated new main commit also invalidates the plan. The main-tip check occurs
just before apply; it does not freeze the branch during deployment.

Saved-plan apply cannot guarantee detection of every direct AWS change made while
approval is pending. Keep review intervals short and replan if infrastructure has
changed. Terraform backend locking and saved-state checks remain enabled.

## Public tutorial data

Plan artifacts in a public repository are accessible to other GitHub users.
Binary plans can contain secrets even when plan.txt redacts them. This public
tutorial must use non-sensitive example infrastructure and values. For real
secrets, use access-controlled plan storage instead of publishing these artifacts.

## Terraform and runner setup

Each app has one configuration in apps/<app>/app.tfvars and a separate backend key
infrastructure/<app>/terraform.tfstate. All apps share the terraform/ root module.
The backend bucket remains hardcoded in terraform/versions.tf and must already
exist. AWS credentials come from the CodeBuild role; no account-ID check is embedded.

Use the existing CodeBuild project ecs-cicd-tutorial-infrastructure and adapt its
runner labels as needed. Runners need bash, git, jq, AWS CLI, GitHub CLI (gh), GNU
date and sha256sum. setup-terraform installs Terraform 1.16.4. Provider versions
are pinned exactly in terraform/versions.tf. Each runner generates its own temporary
.terraform.lock.hcl during init; the file is ignored by Git and is not included in
plan artifacts. No local Terraform initialization is required. This does not affect
S3 state locking (use_lockfile=true), which remains enabled. The role needs
state/locking access and permissions for managed resources.
GitHub CLI uses GH_TOKEN from the job token; no interactive gh login is needed.
The PR comment job needs pull-requests: write. Fork and Dependabot PRs are skipped
because CodeBuild runners carry AWS credentials.

Different apps run in parallel; jobs for the same app share a concurrency group.
GitHub concurrency is not a durable FIFO queue: pending jobs may be superseded.
All planning matrix jobs must succeed before the apply matrix is eligible.

PR detection uses the merge base; main detection compares the pushed commit to
its first parent. Merge commits and squash merges fit this approach. For rebase
merges or multi-commit pushes, use the push's before..sha range instead. Direct
main pushes also generate plans but still need approval before applying.
Changes under this folder's apps/** select affected apps. Shared terraform/**
changes select all apps automatically. Base changes do not run these workflows. Deleted/renamed apps fail discovery rather than
implicitly destroying resources.

The current Terraform root declares locals and outputs, not managed AWS resources.
Applying it records state/outputs but does not yet create ECS services.
