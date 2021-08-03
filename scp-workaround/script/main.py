import json
import os
import boto3

boundaryArn = os.environ['SCP_BOUNDARY_POLICY_ARN']
iam_client = boto3.client('iam')

def lambda_handler(event, context):
    if event['detail']['eventName'] == "CreateUser":
        User_Name = event['detail']['responseElements']['user']['userName']
        identityArn = event['detail']['responseElements']['user']['arn']
        iam_client.put_user_permissions_boundary(
            UserName=User_Name,
            PermissionsBoundary=boundaryArn
        )

    elif event['detail']['eventName'] == "CreateRole":
        identityArn = event['detail']['responseElements']['role']['arn']
        Role_Name = identityArn.split('/')[-1]
        iam_client.put_role_permissions_boundary(
            RoleName=Role_Name,
            PermissionsBoundary=boundaryArn
        )
    else:
        print(event['detail']['eventName'])
        return event['detail']['eventName']
    rspAction="Permissions boundary policy has been attached"
    output = {
        "Identity ARN": identityArn,
        "Respond Action": rspAction}
    
    return json.dumps(output)