# the bucket used by cloudtrail
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket_prefix = var.bucket_name
  acl           = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AWSCloudTrailAclCheck",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "cloudtrail.amazonaws.com"
            ]
          },
          "Action" : "s3:GetBucketAcl",
          "Resource" : "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.cloudtrail_bucket.bucket}"
        },
        {
          "Sid" : "AWSCloudTrailWrite",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "cloudtrail.amazonaws.com"
            ]
          },
          "Action" : "s3:PutObject",
          "Resource" : "arn:${data.aws_partition.current.partition}:s3:::${aws_s3_bucket.cloudtrail_bucket.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
          "Condition" : {
            "StringEquals" : {
              "s3:x-amz-acl" : "bucket-owner-full-control"
            }
          }
        }
      ]
    }
  )
}

resource "aws_cloudtrail" "org_cloudtrail" {
  name                       = var.trail_name
  s3_bucket_name             = aws_s3_bucket.cloudtrail_bucket.bucket
  enable_log_file_validation = true
  is_multi_region_trail      = true
  tags                       = local.tags
}
