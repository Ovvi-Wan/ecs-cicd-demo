data "aws_partition" "current" {}

locals {
  state_bucket_arn   = "arn:${data.aws_partition.current.partition}:s3:::${var.project_prefix}-tfstate-${var.aws_account_id}-${var.aws_region}"
  project_role_arn   = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${var.project_prefix}-*"
  project_policy_arn = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:policy/${var.project_prefix}-*"
}

resource "aws_cloudwatch_log_group" "runner" {
  for_each          = var.runner_projects
  name              = "/aws/codebuild/${var.project_prefix}-${each.key}"
  retention_in_days = 14
}

resource "aws_iam_role" "runner" {
  for_each = var.runner_projects
  name     = "${var.project_prefix}-${each.key}-runner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
        ArnEquals = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:codebuild:${var.aws_region}:${var.aws_account_id}:project/${var.project_prefix}-${each.key}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "runner" {
  for_each = var.runner_projects
  name     = "runner-operation"
  role     = aws_iam_role.runner[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.runner[each.key].arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["codeconnections:GetConnection", "codeconnections:GetConnectionToken"]
        Resource = var.github_connection_arn
      }
    ]
  })
}

resource "aws_codebuild_project" "runner" {
  for_each           = var.runner_projects
  name               = "${var.project_prefix}-${each.key}"
  description        = "Ephemeral GitHub Actions runner for ${each.value.repository}"
  service_role       = aws_iam_role.runner[each.key].arn
  build_timeout      = 15
  queued_timeout     = 15
  project_visibility = "PRIVATE"

  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = each.value.privileged_mode
    host_kernel                 = "LINUX_KERNEL_LATEST"

    # This infrastructure runner currently serves dev only.
    dynamic "environment_variable" {
      for_each = each.key == "infrastructure" ? ["dev"] : []
      content {
        name  = "LIFECYCLE"
        value = environment_variable.value
        type  = "PLAINTEXT"
      }
    }
  }
  source {
    type            = "GITHUB"
    location        = "https://github.com/${each.value.repository}.git"
    git_clone_depth = 1
    auth {
      type     = "CODECONNECTIONS"
      resource = var.github_connection_arn
    }
  }
  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.runner[each.key].name
    }
  }

  depends_on = [aws_iam_role_policy.runner, aws_iam_role_policy.infrastructure, aws_iam_role_policy.image_build]
}

resource "aws_codebuild_webhook" "runner" {
  for_each     = var.runner_projects
  project_name = aws_codebuild_project.runner[each.key].name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

resource "aws_iam_role_policy" "image_build" {
  name = "image-build-ecr"
  role = aws_iam_role.runner["application"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ManageECR"
      Effect   = "Allow"
      Action   = "ecr:*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "infrastructure" {
  name = "infrastructure-deployment"
  role = aws_iam_role.runner["infrastructure"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageContainerInfrastructure"
        Effect = "Allow"
        Action = [
          "ecs:*", "elasticloadbalancing:*", "ecr:*",
          "application-autoscaling:*", "logs:*", "secretsmanager:*",
          "cloudwatch:DescribeAlarms", "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms",
          "cloudwatch:EnableAlarmActions", "cloudwatch:DisableAlarmActions",
          "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageVPCNetworking"
        Effect = "Allow"
        Action = [
          "ec2:Describe*", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation",
          "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
          "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
          "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:GetRole", "iam:UpdateRole", "iam:DeleteRole",
          "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = local.project_role_arn
      },
      {
        Sid    = "ManageProjectPolicies"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy", "iam:UntagPolicy"
        ]
        Resource = local.project_policy_arn
      },
      {
        Sid    = "ReadPolicies"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions",
          "iam:ListPolicyTags", "iam:ListEntitiesForPolicy"
        ]
        Resource = [
          local.project_policy_arn,
          "arn:${data.aws_partition.current.partition}:iam::aws:policy/*"
        ]
      },
      {
        Sid      = "PassProjectRolesToECSTasks"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = local.project_role_arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
      {
        Sid      = "CreateRequiredServiceLinkedRoles"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/aws-service-role/*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "ecs.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "ecs.application-autoscaling.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid      = "ListTerraformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = local.state_bucket_arn
      },
      {
        Sid      = "ReadWriteTerraformState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${local.state_bucket_arn}/*"
      },
      {
        Sid      = "ReleaseTerraformStateLocks"
        Effect   = "Allow"
        Action   = "s3:DeleteObject"
        Resource = "${local.state_bucket_arn}/*.tflock"
      }
    ]
  })
}