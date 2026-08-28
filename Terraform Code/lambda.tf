//Declare A Lambda function named "genai-bedrock-api-handler"
resource "aws_lambda_function" "genai_bedrock_api_handler" {
  function_name = "genai-bedrock-api-handler"
  role          = aws_iam_role.LambdaBedrockAPIRole.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  environment {
    variables = {
      MODEL_ID         = var.bedrock_model_id
    }
  }

  filename = "lambda_function.zip"

  source_code_hash = filebase64sha256("lambda_function.zip")
}


// Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.genai_bedrock_api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.genai_serverless_api.execution_arn}/*/*"
}