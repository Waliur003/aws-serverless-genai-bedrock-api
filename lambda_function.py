import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize Bedrock Runtime client
bedrock_client = boto3.client(
    service_name="bedrock-runtime",
    region_name=os.environ.get("AWS_REGION", "us-east-1")
)

# Active first-party Bedrock foundation model
MODEL_ID = os.environ.get("MODEL_ID", "amazon.nova-micro-v1:0")

def lambda_handler(event, context):
    cors_headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,X-Api-Key"
    }

    # Handle CORS preflight OPTIONS request
    if event.get("httpMethod") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": ""
        }

    try:
        # Handle payload parsing from API Gateway or direct Lambda test
        body = event.get("body")
        if isinstance(body, str):
            payload = json.loads(body)
        elif isinstance(body, dict):
            payload = body
        else:
            payload = event

        prompt = payload.get("prompt")
        if not prompt or not prompt.strip():
            return {
                "statusCode": 400,
                "headers": cors_headers,
                "body": json.dumps({"error": "Field 'prompt' is required."})
            }

        max_tokens = int(payload.get("max_tokens", 512))
        temperature = float(payload.get("temperature", 0.5))

        # Invoke Bedrock Converse API
        response = bedrock_client.converse(
            modelId=MODEL_ID,
            messages=[
                {
                    "role": "user",
                    "content": [{"text": prompt}]
                }
            ],
            inferenceConfig={
                "maxTokens": max_tokens,
                "temperature": temperature
            }
        )

        # Extract generated content and token metrics
        generated_text = response["output"]["message"]["content"][0]["text"]
        token_usage = response.get("usage", {})

        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps({
                "model": MODEL_ID,
                "result": generated_text,
                "usage": {
                    "input_tokens": token_usage.get("inputTokens", 0),
                    "output_tokens": token_usage.get("outputTokens", 0),
                    "total_tokens": token_usage.get("totalTokens", 0)
                }
            })
        }

    except ClientError as e:
        error_msg = e.response["Error"]["Message"]
        return {
            "statusCode": 502,
            "headers": cors_headers,
            "body": json.dumps({"error": f"Bedrock Error: {error_msg}"})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": f"Internal Server Error: {str(e)}"})
        }