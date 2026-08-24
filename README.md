# AI Cloud Engineering Project 1: Serverless GenAI API with Amazon Bedrock (API Gateway, AWS Lambda & Least-Privilege IAM)

---

## Overview

I have architected and deployed a production-grade, fully serverless Generative AI inference API on AWS powered by **Amazon Bedrock**. Built according to modern cloud architecture and least-privilege security principles, this system exposes a scalable HTTP endpoint that ingests client prompts, invokes serverless foundation models (**Amazon Nova Micro** via the Bedrock Converse API), and streams back generated completions alongside real-time token usage telemetry.

The compute tier runs on an optimized **AWS Lambda** runtime (**Python 3.12** on **AWS Graviton** `arm64`) integrated with **Amazon API Gateway** via proxy integration. By offloading LLM compute entirely to managed foundation models, this architecture completely eliminates the overhead of managing self-hosted GPU infrastructure such as Amazon EC2 `g5` or `p4d` instances while achieving sub-second cold starts and zero idle operational costs.

---

## The Problem

Deploying Generative AI applications into production environments presents significant operational, architectural, and security challenges when using traditional compute designs.

### Heavy GPU Cluster Provisioning Overhead & Idle Costs

Hosting open-source LLMs on self-managed EC2 GPU clusters requires dedicated capacity reservations, complex model serving runtimes such as vLLM or TGI, and high baseline infrastructure costs even when traffic is completely idle.

### Insecure API Key Management & Credential Leaks

Calling third-party SaaS model providers directly from frontend clients or hardcoding vendor API tokens inside compute environments exposes organizations to credential exfiltration, uncontrolled token billing, and unauthorized access.

### Integration Timeouts & Default Runtime Bottlenecks

Standard serverless compute runtimes default to conservative 3-second execution timeouts. Generative model invocations requiring complex multi-token generations frequently breach these thresholds, causing abrupt connection drops and `504 Gateway Timeout` errors.

---

## The Solution

### Zero-Infrastructure Serverless LLM Invocations

Utilized **Amazon Bedrock** on-demand serverless endpoints, allowing the application to invoke enterprise-grade foundation models on a pay-per-token basis without managing GPU instances, model drivers, or scaling policies.

### Scoped Least-Privilege IAM Role Chaining

Provisioned a dedicated execution role (`LambdaBedrockAPIRole`) attached to a tightly scoped custom IAM policy (`BedrockInvokeLeastPrivilegePolicy`). Lambda is granted permissions strictly to `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` without broad administrative privileges.

### High-Performance Graviton Serverless Compute

Deployed backend orchestration logic to **AWS Lambda** compiled on Graviton (`arm64`) architecture with memory tuned to **256 MB** and execution timeout configured to **30 seconds**, ensuring sufficient overhead for deep token generation while minimizing compute latency.

### RESTful Edge Ingress with Amazon API Gateway

Exposed a Regional **Amazon API Gateway REST API** (`genai-serverless-api`) utilizing Lambda Proxy Integration on `/generate`, handling request payload parsing, CORS preflight validation, and status code encapsulation.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **API & Edge Ingress** | Amazon API Gateway REST API (`genai-serverless-api` / `9rhea5lkqf`) |
| **Serverless Compute** | AWS Lambda (`genai-bedrock-api-handler` – Python 3.12 / Graviton `arm64`) |
| **Foundation Model** | Amazon Bedrock (`amazon.nova-micro-v1:0` via Bedrock Converse API) |
| **Security & IAM** | AWS IAM (`LambdaBedrockAPIRole`, `BedrockInvokeLeastPrivilegePolicy`) |
| **Observability & Logging** | Amazon CloudWatch Logs (`/aws/lambda/genai-bedrock-api-handler`) |
| **SDK & Orchestration** | AWS SDK for Python (**Boto3**), BotoCore Client Exceptions |
| **Infrastructure as Code** | HashiCorp Terraform |

---

## Architecture Diagram
<img width="1169" height="827" alt="Architecture Diagram" src="https://github.com/user-attachments/assets/b08b3e44-0588-409e-ba08-71f62254c4b7" />


---

## Project Procedure

### 1. Amazon Bedrock Model Access & Runtime Validation

* Accessed the **Amazon Bedrock Console** in `us-east-1` (N. Virginia) and verified model availability across first-party and third-party foundation models.
* Configured the inference pipeline to target **Amazon Nova Micro** (`amazon.nova-micro-v1:0`) for ultra-low latency, serverless execution, and cost efficiency.

---

### 2. Least-Privilege IAM Policy & Execution Role Provisioning

#### Custom IAM Policy Creation

Authored `BedrockInvokeLeastPrivilegePolicy` in the IAM Console to strictly permit Bedrock model invocation and CloudWatch logging:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:*::foundation-model/*",
        "arn:aws:bedrock:*:*:inference-profile/*"
      ]
    },
    {
      "Sid": "CloudWatchLoggingPermissions",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/*"
    }
  ]
}
```

#### Execution Role Assembly

Provisioned IAM Role `LambdaBedrockAPIRole`:

```text
arn:aws:iam::418272769771:role/LambdaBedrockAPIRole
```

The role uses a trust policy allowing `lambda.amazonaws.com` to assume the role.

---

### 3. AWS Lambda Function Authoring & Bedrock Converse API Integration

#### Function Provisioning

Deployed `genai-bedrock-api-handler` with runtime **Python 3.12** on `arm64`.

#### Configuration Tuning

Scaled memory to **256 MB** and adjusted execution timeout from 3 seconds to **30 seconds** to prevent generative processing timeouts.

#### Application Logic

Integrated Boto3's modern `converse()` API to dynamically accept custom parameters:

* `prompt`
* `temperature`
* `max_tokens`

The function also parses output token counts:

* `inputTokens`
* `outputTokens`
* `totalTokens`

---

### 4. Amazon API Gateway REST Resource & Proxy Integration Deployment

#### REST API Provisioning

Created Regional API `genai-serverless-api`:

```text
9rhea5lkqf
```

#### Resource & Method Mapping

Created path resource `/generate` with a `POST` method configured with **Lambda Proxy Integration** targeting `genai-bedrock-api-handler`.

#### Stage Deployment

Deployed the API to the `dev` stage, generating the production invoke URL:

```text
https://9rhea5lkqf.execute-api.us-east-1.amazonaws.com/dev/generate
```

---

## Infrastructure as Code (IaC) Architecture

To ensure repeatable and automated deployments across development, staging, and production environments, the infrastructure is modularized using HashiCorp Terraform:

```text
terraform-aws-bedrock-api/
├── main.tf                # Provider configuration (AWS us-east-1) and local variables
├── variables.tf           # Parameterized region, environment name, and Bedrock model IDs
├── iam.tf                 # IAM execution role and scoped least-privilege Bedrock policies
├── lambda.tf              # Lambda function resource, code packaging, and timeout settings
├── apigateway.tf          # REST API Gateway, /generate resource, POST proxy method, and dev stage
├── cloudwatch.tf          # CloudWatch log group definition with 14-day retention rule
├── outputs.tf             # Exported API Gateway Invoke URL and Lambda Function ARN
└── src/
    └── lambda_function.py # Python 3.12 Bedrock Converse handler
```

---

## Detailed File-by-File Technical Breakdown

### `main.tf`

Initializes the AWS provider in `us-east-1` and defines default tags:

```text
Environment = "dev"
Project     = "ServerlessGenAI"
```

### `variables.tf`

Parameterizes the target Bedrock foundation model ID (`amazon.nova-micro-v1:0`), compute architecture (`arm64`), and deployment stage.

### `iam.tf`

Enforces least privilege by granting the Lambda service principal `sts:AssumeRole` permissions and binding access strictly to `bedrock:InvokeModel`.

### `lambda.tf`

Uses `data "archive_file"` to package the Python source code, provisions the function with a 30-second timeout, and attaches `aws_lambda_permission` to allow API Gateway invocation.

### `apigateway.tf`

Defines the REST API, `/generate` resource, `POST` proxy integration, deployment triggers, and the live `dev` stage.

### `cloudwatch.tf`

Manages `/aws/lambda/genai-bedrock-api-handler` log streams with automated log retention policies.

### `outputs.tf`

Exports the public HTTP endpoint (`api_invoke_url`) for automated integration testing.

---

## Technical Difficulties Faced & Engineering Resolutions

### Challenge 1: Deprecated Model ID Causing `ResourceNotFoundException`

#### Root Cause Analysis

During initial Lambda testing with legacy Claude 3 Haiku (`anthropic.claude-3-haiku-20240307-v1:0`), Amazon Bedrock returned a `502 Bad Gateway` error with `ResourceNotFoundException: Access denied. This model version has reached the end of its life.` AWS Bedrock regularly sunsets older model iterations in favor of active models.

#### Architectural Resolution

Updated the application architecture to use AWS's active first-party foundation model **Amazon Nova Micro** (`amazon.nova-micro-v1:0`). This model works natively with zero additional marketplace approvals, features lower token costs, and provides sub-second inference speeds.

---

### Challenge 2: Lambda Execution Timeout Bottlenecks

#### Root Cause Analysis

The default AWS Lambda execution timeout of 3 seconds is inadequate for generative LLM inference. When generating multi-sentence completions, the Bedrock API call typically requires 4–12 seconds, resulting in immediate execution timeouts.

#### Architectural Resolution

Increased the Lambda function timeout configuration to **30 seconds** and expanded memory allocation to **256 MB**, which provides higher burst CPU allocation on the underlying AWS Graviton instance to accelerate TLS handshakes and JSON payload serialization.

---

### Challenge 3: Dual-Mode Event Payload Parsing

#### Root Cause Analysis

When testing directly inside the Lambda console, the input payload is delivered as a raw Python `dict`. However, when forwarded through API Gateway's Proxy Integration, the request body is delivered as a stringified JSON property (`event['body']`), causing serialization errors if not handled dynamically.

#### Architectural Resolution

Implemented resilient payload parsing in Python:

```python
body = event.get("body")
if isinstance(body, str):
    payload = json.loads(body)
elif isinstance(body, dict):
    payload = body
else:
    payload = event
```

---

## Verification and Results

### Verified Scoped IAM Execution Role

Successfully created and verified `LambdaBedrockAPIRole` with the attached `BedrockInvokeLeastPrivilegePolicy`, restricting model invocation permissions strictly to authorized inference resources.

### Validated AWS Lambda Function Configuration

Configured `genai-bedrock-api-handler` with Python 3.12 on Graviton (`arm64`), 256 MB memory, and a 30-second timeout, ensuring zero cold-start bottlenecks during generation.

### Confirmed Bedrock Inference & Token Usage Metrics

Successfully executed direct test events against the Bedrock Converse API, returning HTTP status `200 OK` with complete completion text and exact token telemetry:

```text
input_tokens: 9
output_tokens: 46
total_tokens: 55
```

### Validated Live Public API Gateway HTTP Invocations

Executed remote `cURL` POST requests to the public API Gateway endpoint, confirming sub-second end-to-end delivery:

```bash
curl -X POST https://9rhea5lkqf.execute-api.us-east-1.amazonaws.com/dev/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is Infrastructure as Code in two sentences?",
    "temperature": 0.3,
    "max_tokens": 150
  }'
```

#### Verified JSON Output

```json
{
  "model": "amazon.nova-micro-v1:0",
  "result": "Infrastructure as Code (IaC) is a practice where infrastructure is provisioned and managed using machine-readable configuration files, rather than physical hardware or pre-configured images. This approach enables automation, version control, and scalability in managing IT environments.",
  "usage": {
    "input_tokens": 9,
    "output_tokens": 51,
    "total_tokens": 60
  }
}
```

---

## Verification Screenshots

### 1. IAM Execution Role & Scoped Bedrock Policy (`LambdaBedrockAPIRole`)

Displays the `LambdaBedrockAPIRole` (`arn:aws:iam::418272769771:role/LambdaBedrockAPIRole`) successfully provisioned in the AWS IAM Console with the attached customer-managed policy `BedrockInvokeLeastPrivilegePolicy`.

<img width="1916" height="906" alt="Screenshot 1" src="https://github.com/user-attachments/assets/4c3fe845-51ec-4494-adbf-5dac63b661dd" />


### 2. AWS Lambda Function Configuration (`genai-bedrock-api-handler`)

Shows the AWS Lambda configuration interface verifying that memory is tuned to 256 MB, ephemeral storage to 512 MB, and execution timeout to 30 seconds for the `genai-bedrock-api-handler` function.

<img width="1919" height="720" alt="Screenshot 2" src="https://github.com/user-attachments/assets/053e7d59-39f9-409f-a1fe-ad09bfddf79c" />


### 3. AWS Lambda Test Execution & Token Telemetry Output

Displays the successful execution of the test event inside the AWS Lambda console. The response returns HTTP `200 OK` along with the JSON payload containing the Bedrock Nova Micro response and token telemetry (`input_tokens: 9`, `output_tokens: 46`, `total_tokens: 55`).

<img width="1599" height="678" alt="Screenshot 3" src="https://github.com/user-attachments/assets/8ac402b3-4607-4f0a-bc9f-ab897f72048e" />


### 4. End-to-End Live API Gateway `cURL` Verification

Captures a live terminal executing a `cURL` POST request against the deployed Amazon API Gateway endpoint (`https://9rhea5lkqf.execute-api.us-east-1.amazonaws.com/dev/generate`). The API returns a `200 OK` response with generated LLM text and token metrics in real time.

<img width="1447" height="545" alt="Screenshot 4" src="https://github.com/user-attachments/assets/563cf275-bcd0-43d4-a4e0-223383d48966" />

---

## Future Improvements

### API Gateway Rate Limiting & Usage Plans

Implement API Keys and Throttling Limits, such as 50 requests/second and 100 burst, to prevent denial-of-wallet attacks and abuse.

### AWS WAF Edge Protection

Attach an AWS WAF Web ACL to the API Gateway stage to filter malicious payloads and enforce rate-based IP blocking.

### Asynchronous Buffer with Amazon SQS

For long-running prompts or batch document summaries, introduce an SQS queue between API Gateway and Lambda to convert synchronous calls into resilient asynchronous jobs.

---

## Notes

This project demonstrates a production-grade blueprint for integrating generative foundation models into enterprise cloud environments. By leveraging Amazon Bedrock alongside AWS Lambda and API Gateway, teams can build secure, resilient, and auto-scaling AI microservices without provisioning or maintaining expensive dedicated GPU infrastructure.

---

## Bottom Line

The Serverless GenAI API architecture demonstrates modern cloud engineering principles by decoupling public API ingestion from foundation model inference. By enforcing least-privilege IAM policies, utilizing AWS Graviton compute, and tapping into Amazon Bedrock via the unified Converse API, this system delivers scalable, cost-optimized, and observable AI infrastructure ready for enterprise integration.
