// Declare IAM policy document for Bedrock
data "aws_iam_policy_document" "bedrock_policy" {
  statement {
    sid    = "BedrockInvokeCrossRegionAccess"
    effect = "Allow"

    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]

    resources = [
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:*:inference-profile/*",
    ]
  }

  statement {
    sid    = "CloudWatchLoggingPermissions"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/*",
    ]
  }
}


// Declare Iam policy Named "BedrockInvokeLeastPrivilegePolicy" to attch with the previous policy document
resource "aws_iam_policy" "bedrock_invoke_least_privilege_policy" {
  name        = "BedrockInvokeLeastPrivilegePolicy"
  description = "IAM policy for Bedrock model invocation with least privilege"
  policy      = data.aws_iam_policy_document.bedrock_policy.json
}


// Declare IAM role for Lambda function with assume role policy allowing Lambda service to assume the role  
resource "aws_iam_role" "LambdaBedrockAPIRole" {
    name = "LambdaExecutionRole"
    
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        }
        ]
    })
}


// Attach the BedrockInvokeLeastPrivilegePolicy to the LambdaBedrockAPIRole
resource "aws_iam_role_policy_attachment" "attach_bedrock_policy" {
  role       = aws_iam_role.LambdaBedrockAPIRole.name
  policy_arn = aws_iam_policy.bedrock_invoke_least_privilege_policy.arn
}

