# Application IAM policies

1. Write a normal AWS IAM JSON policy in this folder.
2. Set its path in app.tfvars:

```hcl
iam = {
  task_policy_file = "policies/task-policy.json"
}
```

Terraform reads the single file directly, passes its JSON to the IAM module, creates
one managed policy, and attaches it to the application task role. Omit
`task_policy_file` or set it to null to create no custom app policy. Files are not
attached automatically. Combine permissions using multiple statements in this file.
The example permits reading objects under an S3 bucket prefix;
replace the bucket and prefix with your application's actual resources.

There are no Terraform templates, injected variables, or special placeholders.
Write actual resource ARNs. Native AWS IAM policy variables such as ${aws:username}
remain unchanged. JSON cannot contain comments; use Sid for short statement labels
and this README for explanations. Never put credentials in policy files.

The execution role is separate: Terraform automatically grants startup access to
the app's ECR repository, log group and configured secrets.
You only write permissions needed by application code. Secret environment injection
does not require a task-role policy; reading a secret through the application SDK does.

Optional iam.task_managed_policy_arns attaches policies that already exist.
iam.permissions_boundary_arn applies an existing boundary to both task roles.
A boundary limits permissions but does not grant them.

The managed policy is named `<project>-<environment>-<application>-task-policy`,
independent of the filename. The input accepts one string path, not a list.
