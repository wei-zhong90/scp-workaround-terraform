resource "aws_cloudwatch_event_rule" "monitor_event" {
  name        = "capture-cloudtrail-event"
  description = "Capture each cloudtrail event"

  event_pattern = <<EOF
{
  "source": [
    "aws.iam"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "iam.amazonaws.com"
    ]
  }
}
EOF

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.monitor_event.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.monitor_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitor_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor_event.arn
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = local.tags

}

resource "aws_iam_role_policy_attachment" "function-role-attach1" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "function-role-attach2" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/script/main.py"
  output_path = "${path.module}/script/main.py.zip"
}

resource "aws_lambda_function" "monitor_lambda" {
  filename      = data.archive_file.lambda.output_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "main.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256(data.archive_file.lambda.output_path)

  runtime     = "python3.8"
  timeout     = 30
  memory_size = 128
  environment {
    variables = {
      SCP_BOUNDARY_POLICY_ARN = aws_iam_policy.boundary_policy.arn
    }
  }
  tags = local.tags
}
