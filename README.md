# Automated Billing CSV to Aurora Serverless

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [How It Works](#how-it-works)
- [Tasks and Implementation Steps](#tasks-and-implementation-steps)
- [Local Testing](#local-testing)
- [Lambda Deployment with Environment Variables](#lambda-deployment-with-environment-variables)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered](#errors-encountered)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless ETL pipeline using AWS Lambda, S3, Secrets Manager, and Aurora Serverless. When a billing CSV file is uploaded to an S3 bucket, a Lambda function is triggered. It reads the CSV, converts any non-USD billing amounts into USD, and inserts the cleaned records into an Aurora Serverless MySQL database.

---

## Real-World Business Value

For finance, billing, or data engineering teams managing international transactions, this automation reduces manual processing and enforces a consistent data format for analytics. The project eliminates the risk of currency inconsistency while allowing ingestion into a scalable cloud-native RDS solution. It provides a production-ready framework for real-time, event-driven financial data processing.

---

## Prerequisites

1. Aurora Serverless V1 database cluster (`aurora-billing-cluster`)
2. Secrets Manager secret for DB credentials (`aurora_billing_db_secret`)
3. An S3 bucket for processed billing files (`boto3-billing-processed-*`)
4. Terraform CLI and AWS CLI configured
5. Python 3.11 and `PyMySQL` installed in a virtual environment

---

## Project Folder Structure

```
automated-billing-csv-to-aurora-serverless/
├── backend/
│   ├── lambda_function.py
│   └── requirements.txt
├── terraform/
│   ├── lambda.tf
│   ├── iam.tf
│   ├── rds.tf
│   ├── s3.tf
│   ├── secrets.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── main.tf
├── lambda_function.zip
├── deploy.sh
└── README.md
```

---

## How It Works

1. A billing CSV file is uploaded to an S3 bucket.
2. The S3 `PUT` event triggers a Lambda function.
3. The function:

   - Downloads and parses the CSV
   - Converts non-USD values into USD
   - Inserts records into Aurora Serverless using the RDS Data API

4. Any issues are logged to CloudWatch for traceability.

### Sample Code Snippet: Currency Conversion

```python
exchange_rates = {"USD": 1, "CAD": 0.75, "MXN": 0.059}
converted = round(float(row[8]) * exchange_rates.get(currency, 1), 2)
```

### Sample Code Snippet: Secure DB Credential Fetch

```python
secret_name = os.environ["DB_SECRET_NAME"]
response = secretsmanager.get_secret_value(SecretId=secret_name)
secret = json.loads(response["SecretString"])
```

---

## Tasks and Implementation Steps

### 1. Write Lambda Code in Python

- Handles currency conversion logic
- Retrieves DB credentials via Secrets Manager
- Executes parameterised SQL inserts with RDS Data API

### 2. Set up IAM Role for Lambda

- Grants access to:

  - S3 bucket (read)
  - RDS Data API (write)
  - Secrets Manager (read)

### 3. Terraform Configuration

- Provisions:

  - Aurora cluster and instances
  - Secrets Manager secret and values
  - S3 bucket
  - Lambda function and IAM roles

### 4. Deployment

Run:

```bash
bash deploy.sh
```

This script:

- Zips `lambda_function.py` and dependencies
- Applies Terraform infrastructure
- Deploys the latest Lambda package

---

## Local Testing

Prepare an S3 trigger `event.json`, then manually test:

```python
from lambda_function import lambda_handler
import json

with open("event.json") as f:
    event = json.load(f)

lambda_handler(event, {})
```

Use this for debugging before pushing to S3.

---

## Lambda Deployment with Environment Variables

Terraform injects secrets and DB config:

```hcl
environment {
  variables = {
    DB_SECRET_NAME = var.db_secret_name
  }
}
```

This allows the Lambda to use `os.environ.get("DB_SECRET_NAME")` to fetch credentials securely.

---

## IAM Role and Permissions

Lambda is granted scoped access via inline policy:

```hcl
policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
    {
      Action = [
        "s3:GetObject",
        "rds-data:ExecuteStatement",
        "secretsmanager:GetSecretValue"
      ],
      Effect = "Allow",
      Resource = "*"
    }
  ]
})
```

---

## Design Decisions and Highlights

- **RDS Data API**: Used to avoid persistent DB connections within Lambda.
- **Currency Conversion Dictionary**: Maintained inside the Lambda for simplicity and transparency.
- **Secrets Manager**: Ensures DB credentials are rotated and secured.
- **Terraform Automation**: Simplifies repeatable infrastructure provisioning.
- **Zip Packaging**: Ensures external libraries (e.g., `PyMySQL`) are bundled properly for Lambda.

---

## Errors Encountered

### ❌ Code Not Updating in Lambda Console

- **Issue**: Terraform reported "No changes" despite code updates.
- **Fix**: Ensured the `.zip` file path referenced in `filename` was updated (`terraform/lambda_function.zip`), and `source_code_hash` was used for versioning.

### ❌ Logging Error: `unexpected error: {e}`

- **Cause**: Placeholder logging format string `{e}` was not interpolated.
- **Fix**: Changed to `logger.error(f"ERROR: Unexpected error: {e}")`.

### ❌ Terraform Apply Not Triggering Redeploy

- **Solution**: Added `source_code_hash = filebase64sha256("lambda_function.zip")` to force update on content change.

---

## Skills Demonstrated

- Secure AWS Lambda-to-RDS integration using the RDS Data API
- Currency-aware billing transformation and ingestion
- Event-driven serverless architecture with S3 triggers
- Clean Terraform infrastructure-as-code with modular design
- Pythonic exception handling and structured logging

---

## Conclusion

This project utilises an effective pattern for automated, secure, and scalable ingestion of financial billing data into Aurora Serverless using Lambda and event-driven S3 uploads. It highlighted cloud engineering (boto3, terraform, bash) best practices in infrastructure automation, secret handling, and real-time data processing.

---
