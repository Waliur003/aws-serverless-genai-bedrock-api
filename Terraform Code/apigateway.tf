//Create aws_api_gateway_rest_api resource named "genai-serverless-api"
resource "aws_api_gateway_rest_api" "genai_serverless_api" {
  name        = "genai-serverless-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


//Create aws_api_gateway_resource resource named "generate" under the root resource of the API Gateway
resource "aws_api_gateway_resource" "generate" {
  rest_api_id = aws_api_gateway_rest_api.genai_serverless_api.id
  parent_id   = aws_api_gateway_rest_api.genai_serverless_api.root_resource_id
  path_part   = "generate"
}


//Create aws_api_gateway_method resource for the "generate" resource with POST method
resource "aws_api_gateway_method" "generate_post" {
  rest_api_id   = aws_api_gateway_rest_api.genai_serverless_api.id
  resource_id   = aws_api_gateway_resource.generate.id
  http_method   = "POST"
  authorization = "NONE"
}


//Create aws_api_gateway_integration resource for the "generate" resource with Lambda integration
resource "aws_api_gateway_integration" "generate_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.genai_serverless_api.id
  resource_id             = aws_api_gateway_resource.generate.id
  http_method             = aws_api_gateway_method.generate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.genai_bedrock_api_handler.invoke_arn
}


//Create aws_api_gateway_deployment resource for the API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.generate_post_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.genai_serverless_api.id
  

  triggers = { redeployment = sha1(jsonencode([aws_api_gateway_resource.generate.id, aws_api_gateway_method.generate_post.id, aws_api_gateway_integration.generate_post_integration.id])) }

}


//Create aws_api_gateway_stage resource for the API Gateway deployment
resource "aws_api_gateway_stage" "stage" {
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.genai_serverless_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
}


