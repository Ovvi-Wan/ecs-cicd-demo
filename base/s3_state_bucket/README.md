# Terraform state bucket

Run from base/s3_state_bucket on an approved bootstrap runner. This root owns the
state bucket, versioning, AES256 encryption, public-access blocking and TLS policy.

## Current configuration

versions.tf already has an ACTIVE S3 backend. If the bucket/resources already exist,
use their current state. Supply required inputs with TF_VAR_* variables or a private
tfvars file; this folder currently has no terraform.tfvars.example.

```bash
terraform init
terraform plan -out=state.tfplan
# Review before applying.
terraform apply state.tfplan
```

## New account without a bucket

Temporarily comment out the backend block on the bootstrap runner, initialize using
local state, plan and apply the bucket. Keep that local state secure and available.
Set the backend bucket to the created bucket, restore the backend block, and run
terraform init -migrate-state in the SAME initialized directory. Approve copying
state, verify the S3 state object exists and check a fresh plan for unexpected changes.
Do not use -reconfigure in place of -migrate-state for this operation.

This is a bootstrap procedure, not an automatic app workflow. No local workstation
execution is required. The role needs bucket management permissions plus state and
lock-object access. Do not commit state or plan files. See [base setup](../README.md).
