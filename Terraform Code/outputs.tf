// Lambda function ARN output
output "lambda_arn" {
  description = "ARN of the Bedrock Lambda handler"
  value       = aws_lambda_function.genai_bedrock_api_handler.arn
}

// Lambda function Invoke ARN output
output "lambda_invoke_arn" {
  description = "Invoke ARN used by API Gateway"
  value       = aws_lambda_function.genai_bedrock_api_handler.invoke_arn
}

// Public API Gateway Endpoint URL
output "api_endpoint_url" {
  description = "Live HTTPS endpoint for GenAI inference"
  value       = "${aws_api_gateway_stage.stage.invoke_url}/generate"
}

// IAM Role ARN
output "iam_role_arn" {
  description = "Execution role attached to Lambda"
  value       = aws_iam_role.LambdaBedrockAPIRole.arn
}