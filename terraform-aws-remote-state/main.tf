terraform {
  required_version = "~> 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 3.38.0"
    }
  }
}

provider "aws" {
  region  = "cn-north-1"
  profile = local.profile
  #allowed_account_ids = [local.yaml_vars.bootstrap.root.account_id]
  default_tags {
    tags = {
      Account     = "Master"
      Description = "Managed by Terraform"
    }
  }
}


locals {
  state_name = var.state_name != "" ? var.state_name : "${var.prefix}-tf-remote-state"
  name_tag   = "Terraform Remote State"
  profile    = var.profile

  ec2_principal = data.aws_partition.current.partition == "aws-cn" ? "ec2.amazonaws.com.cn" : "ec2.amazonaws.com"

  tags = merge(var.tags, {
    ManagedBy = "terraform"
  })

  iam_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3Access",
        Effect = "Allow",
        Action = ["s3:*"],
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.state.bucket}/*"
        ]
      },
      {
        Sid      = "S3ListBucket",
        Effect   = "Allow",
        Action   = "s3:*",
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.state.bucket}"
      },
      {
        Sid      = "KMSListKeys",
        Effect   = "Allow",
        Action   = "kms:ListKeys",
        Resource = "*"
      },
      {
        Sid    = "KMSRead",
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.key.arn
      },
      {
        Sid    = "DynamoDBAccess",
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.table.arn
      }
    ]
  })
}

/**
 * Look up the current account.
 */
data "aws_caller_identity" "self" {}

/**
 * Create a new KMS Key used for encrypting the Remote State bucket.
 */
resource "aws_kms_key" "key" {
  description = "Encryption key for Terraform Remote State"

  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

/**
 * Create the Alias for the KMS Key
 */
resource "aws_kms_alias" "alias" {
  name          = "alias/${local.state_name}"
  target_key_id = aws_kms_key.key.key_id
}

/**
 * Create an S3 Bucket that can be used for logging access to the Remote State bucket.
 */
resource "aws_s3_bucket" "logging" {
  bucket = "${var.state_name}-logs"
  acl    = "log-delivery-write"
}

/**
 * Create an S3 Bucket for the state that is encrypted, has logging, and is versioned.
 */
resource "aws_s3_bucket" "state" {
  bucket_prefix = local.state_name
  acl    = "private"

  depends_on = [aws_kms_key.key]

  logging {
    target_bucket = aws_s3_bucket.logging.id
    target_prefix = "logs/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.key_id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = local.tags
}

/**
 * Create a DynamoDB Table that will be used for locking access to the Remote State.
 */
resource "aws_dynamodb_table" "table" {
  name = local.state_name

  server_side_encryption {
    enabled = true
  }

  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 1

  attribute {
    type = "S"
    name = "LockID"
  }

  tags = local.tags
}

/**
 * Create an IAM group for managing Terraform Remote State.
 */
resource "aws_iam_group" "tf_state" {
  name = "tf-state-management"
  path = "/terraform/"
}

/**
 * Optional - Create an IAM User for managing Terraform Remote State.
 *
 * While using Roles and delegation through AssumeRole seems ideal, it may be preferred
 * to create a Single user with credentials that is shared across AWS Account and Terraform Projects.
 */
resource "aws_iam_user" "user" {
  count = var.create_user ? 1 : 0

  name = var.user_name
}

/**
 * Associates the IAM user with the necessary group.
 */
resource "aws_iam_user_group_membership" "user" {
  count  = var.create_user ? 1 : 0
  user   = aws_iam_user.user[0].name
  groups = [aws_iam_group.tf_state.name]
}

/**
 * Optional - Create IAM Credentials for the User.
 *
 * It may be preferred to manage the Access Key manually to avoid it being stored in state.
 */
resource "aws_iam_access_key" "key" {
  count = var.create_user && var.create_user_credentials ? 1 : 0

  user    = aws_iam_user.user[0].name
  pgp_key = var.pgp_key == null || var.pgp_key == "" ? null : var.pgp_key
}

/**
 * Create an IAM Role for managing Terraform Remote State.
 */
resource "aws_iam_role" "role" {
  path = "/terraform-remote-state/"

  name        = "tf-state-management"
  description = "Terraform Remote State Management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEC2",
        Effect = "Allow",
        Principal = {
          Service = local.ec2_principal
        },
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "AllowPrincipals",
        Effect = "Allow"
        Principal = {
          # If no principals were given then allow within the same account
          AWS = length(var.assume_role_principals) == 0 ? [data.aws_caller_identity.self.account_id] : var.assume_role_principals
        },
        Action = "sts:AssumeRole",
      }
    ]
  })
}

/**
 * IAM policy to allow access to terraform remote state
 */
resource "aws_iam_policy" "iam_policy" {
  name        = "tf-state-management-policy"
  description = "IAM policy to allow access to terraform remote state"
  policy      = local.iam_policy
}

/**
 * Attaches the tf state management access policy to the tf state group.
 */
resource "aws_iam_group_policy_attachment" "group_attachment" {
  group      = aws_iam_group.tf_state.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

/**
 * Attaches the tf state management access policy to the tf state role.
 */
resource "aws_iam_role_policy_attachment" "role_policy_attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}
