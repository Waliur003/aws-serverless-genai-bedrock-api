//Declare the variable for the AWS region.
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

//Declare the variable for the environment.
variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

//Declare the variable for bedrock model id.
variable "bedrock_model_id" {
  description = "The ID of the Bedrock model to use"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

//Declare the variable for the Lambda memory size.
variable "lambda_memory_size" {
  description = "The amount of memory available to the Lambda function in MB"
  type        = number
  default     = 256
}

//Declare the variable for the Lambda timeout.
variable "lambda_timeout" {
  description = "The amount of time that Lambda allows a function to run before stopping it"
  type        = number
  default     = 30
}

//Declare the variable for the CloudWatch log retention days.
variable "cloudwatch_log_retention_days" {
  description = "The number of days to retain CloudWatch logs for the Lambda function"
  type        = number
  default     = 14
}