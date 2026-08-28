//Declare AWS CloudWatch Log Group for the Lambda function
resource "aws_cloudwatch_log_group" "genai_bedrock_api_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.genai_bedrock_api_handler.function_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Environment = var.environment
    Project     = "genai-serverless-api"
  }
}