# terraform {
#   backend "s3" {
#     profile        = "cn"
#     encrypt        = true
#     region         = "cn-north-1"
#     bucket         = "scp-workaround-20210802032019660800000001"
#     dynamodb_table = "scp-workaround-"
#     key            = "scp-workaround" // must be unique across projects
#   }
# }

provider "aws" {
  region  = "cn-north-1"
  profile = var.profile
  default_tags {
    tags = {
      Account     = "Master"
      Description = "Managed by Terraform"
      Owner       = "SCP-Supervisor"
    }
  }
}

locals {
  tags = var.tags
}
