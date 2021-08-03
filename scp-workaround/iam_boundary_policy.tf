resource "aws_iam_policy" "boundary_policy" {
  name        = "boundary_policy"
  path        = "/"
  description = "The boundary policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEverythingElse",
        "Effect" : "Allow",
        "Action" : "*",
        "Resource" : "*"
      },
      {
        "Sid" : "DenyNetworkAccess",
        "Effect" : "Deny",
        "Action" : [
          "ec2:DeleteTransitGatewayConnectPeer",
          "ec2:CreateVpcEndpointConnectionNotification",
          "ec2:CreateTransitGatewayConnect",
          "ec2:DeleteVpcEndpoints",
          "ec2:DeleteVpcPeeringConnection",
          "ec2:CreateTransitGatewayRouteTable",
          "ec2:CreateNatGateway",
          "ec2:CreateTransitGatewayConnectPeer",
          "ec2:CreateTransitGateway",
          "ec2:DeleteVpcEndpointServiceConfigurations",
          "ec2:CreateVpcEndpointServiceConfiguration",
          "ec2:DeleteTransitGatewayRouteTable",
          "ec2:CreateTransitGatewayRoute",
          "ec2:DeleteTransitGatewayRoute",
          "ec2:CreateTransitGatewayVpcAttachment",
          "ec2:DeleteVpcEndpointConnectionNotifications",
          "ec2:CreateVpcEndpoint",
          "ec2:CreateInternetGateway",
          "ec2:DeleteTransitGatewayConnect",
          "ec2:DeleteInternetGateway",
          "ec2:CreateEgressOnlyInternetGateway",
          "ec2:DeleteTransitGateway",
          "ec2:CreateVpcPeeringConnection"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "ProtectBoundary",
        "Effect" : "Deny",
        "Action" : [
          "iam:DeleteUserPermissionsBoundary",
          "iam:DeleteRolePermissionsBoundary"
        ],
        "Resource" : [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/*",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:user/*"
        ],
        "Condition" : {
          "ArnEquals" : {
            "iam:PermissionsBoundary" : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/boundary_policy"
          }
        }
      },
      {
        "Sid" : "DenyTaggedResource",
        "Effect" : "Deny",
        "Action" : "*",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/Owner" : "SCP-Supervisor"
          }
        }
      },
      {
        "Sid" : "ProtectSCPresource",
        "Effect" : "Deny",
        "Action" : "*",
        "Resource" : [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/boundary_policy",
          "${aws_cloudtrail.org_cloudtrail.arn}",
          "${aws_s3_bucket.cloudtrail_bucket.arn}",
          "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_function_name}",
          "${aws_cloudwatch_event_rule.monitor_event.arn}"
        ]
      }
    ]
  })
  tags = local.tags
}

