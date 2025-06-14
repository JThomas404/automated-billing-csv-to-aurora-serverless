# Automated Billing CSV to Aurora Serverless

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [How the Lambda Function Works](#how-the-lambda-function-works)
- [Lambda Function Script Breakdown](#lambda-function-script-breakdown)
- [Tasks and IaC Implementation Steps](#tasks-and-iac-implementation-steps)
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

For finance, billing, or data engineering teams managing international transactions, this automation reduces manual processing and enforces consistent data formatting for analytics. The project eliminates the risk of currency inconsistencies and allows ingestion into a scalable cloud-native RDS solution, providing a production-ready framework for real-time, event-driven financial data processing.

---

## Prerequisites

- Aurora Serverless V2 database cluster (`aurora-billing-cluster`)
- AWS Secrets Manager secret for DB credentials (`aurora_billing_db_secret`)
- An S3 bucket for billing CSV uploads (`boto3-billing-processed-*`)
- Terraform CLI and AWS CLI configured
- Python 3.11 and `PyMySQL` installed in a virtual environment

---

## Project Folder Structure

```

automated-billing-csv-to-aurora-serverless/
├── build/
├── lambda/
│   ├── event.json
│   └── lambda\_function.py
├── README.md
├── requirements.txt
├── deploy.sh
├── s3\_files/
│   ├── billing\_data\_bakery\_june\_2025.csv
│   ├── billing\_data\_dairy\_june\_2025.csv
│   └── billing\_data\_meat\_june\_2025.csv
├── terraform/
│   ├── iam.tf
│   ├── lambda\_function.zip
│   ├── lambda.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── rds.tf
│   ├── s3.tf
│   ├── secrets.tf
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   ├── terraform.tfvars
│   └── variables.tf
└── venv/

```

---

## How the Lambda Function Works

1. A billing CSV file is uploaded to an S3 bucket.
2. The S3 `PUT` event triggers a Lambda function.
3. The function:
   - Downloads and parses the CSV file
   - Converts non-USD values to USD
   - Inserts the data into Aurora Serverless using the Direct PyMySQL Connection
4. Logs execution and errors to CloudWatch for traceability.

### Currency Conversion

```python
exchange_rates = {"USD": 1, "CAD": 0.75, "MXN": 0.059}
converted = round(float(row[8]) * exchange_rates.get(currency, 1), 2)
```

### Secure Secret Fetch from Secrets Manager

```python
secret_name = os.environ["DB_SECRET_NAME"]
response = secretsmanager.get_secret_value(SecretId=secret_name)
secret = json.loads(response["SecretString"])
```

---

## Lambda Function Script Breakdown

### Imports and Initial Setup

```python
import json
import boto3
import pymysql
import csv
import os
import logging
import io
```

### Currency Conversion Setup

```python
currency_conversion_to_usd = {
    'USD': 1,
    'CAD': 0.79,
    'MXN': 0.05
}
```

This dictionary maps supported currencies to their USD equivalents.

### AWS Service Configuration

```python
database_name = 'boto3_rds_instance'
secrets_store_arn = 'arn:aws:secretsmanager:us-east-1:533267010082:secret:aurora_billing_db_secret-tw5Ix6'
db_cluster_arn = 'arn:aws:rds:us-east-1:533267010082:cluster:aurora-billing-cluster'

s3_client = boto3.client('s3')
rds_client = boto3.client('rds-data')

logger = logging.getLogger()
logger.setLevel(logging.INFO)
```

### Record Processing Function

```python
def process_record(record):
    id, company_name, country, city, product_line, item, bill_date, currency, bill_amount = record
    bill_amount = float(bill_amount)

    rate = currency_conversion_to_usd.get(currency)
    if not rate:
        logger.info(f"No rate found for currency: {currency}")
        return

    usd_amount = bill_amount * rate

    sql_statement = """
        INSERT IGNORE INTO billing_data
        (id, company_name, country, city, product_line, item, bill_date, currency, bill_amount, bill_amount_usd)
        VALUES (:id, :company_name, :country, :city, :product_line, :item, :bill_date, :currency, :bill_amount, :usd_amount)
    """

    sql_parameters = [
        {'name': 'id', 'value': {'stringValue': id}},
        {'name': 'company_name', 'value': {'stringValue': company_name}},
        {'name': 'country', 'value': {'stringValue': country}},
        {'name': 'city', 'value': {'stringValue': city}},
        {'name': 'product_line', 'value': {'stringValue': product_line}},
        {'name': 'item', 'value': {'stringValue': item}},
        {'name': 'bill_date', 'value': {'stringValue': bill_date}},
        {'name': 'currency', 'value': {'stringValue': currency}},
        {'name': 'bill_amount', 'value': {'doubleValue': bill_amount}},
        {'name': 'usd_amount', 'value': {'doubleValue': usd_amount}},
    ]

    response = execute_statement(sql_statement, sql_parameters)
    logger.info(f"SQL execution response: {response}")
```

### SQL Execution Function

```python
def execute_statement(sql, sql_parameters):
    try:
        return rds_client.execute_statement(
            secretArn=secrets_store_arn,
            database=database_name,
            resourceArn=db_cluster_arn,
            sql=sql,
            parameters=sql_parameters
        )
    except Exception as e:
        logger.error(f"ERROR: Could not connect to Aurora Serverless MySQL instance: {e}")
        return None
```

This function securely executes parameterised SQL queries on Aurora Serverless.

### Lambda Entry Point

```python
def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        s3_file = event['Records'][0]['s3']['object']['key']
        response = s3_client.get_object(Bucket=bucket_name, Key=s3_file)
        data = response['Body'].read().decode('utf-8')

        csv_reader = csv.reader(io.StringIO(data))
        next(csv_reader)

        for record in csv_reader:
            process_record(record)

        logger.info("Lambda execution finished successfully.")

    except Exception as e:
        logger.error(f"ERROR: Unexpected error: {e}")
```

---

## Tasks and IaC Implementation Steps

### 1. Lambda Code in Python

- Converts billing amounts to USD
- Retrieves DB credentials from Secrets Manager
- Inserts rows using parameterised SQL

### 2. Set Up IAM Role

Grants the Lambda function access to:

- Read from S3
- Write to Aurora
- Read from Secrets Manager

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "lambda_rds_data_api_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
```

### 3. Terraform Infrastructure

Provisions:

- Aurora cluster and instances
- Secrets Manager secret
- S3 bucket
- Lambda function
- IAM roles and permissions

#### `terraform/rds.tf` Example

```hcl
resource "aws_rds_cluster" "aurora_billing_cluster" {
  cluster_identifier     = "aurora-billing-cluster"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.02.0"
  database_name          = "billing_db"
  master_username        = "admin"
  master_password        = var.db_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

resource "aws_rds_cluster_instance" "aurora_billing_instance" {
  count              = 2
  cluster_identifier = aws_rds_cluster.aurora_billing_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_billing_cluster.engine
}
```

### 4. Deployment

Run the following to deploy:

```bash
bash deploy.sh
```

This script:

- Zips the Lambda code
- Applies the updated Terraform infrastructure
- Redeploys the function if there are changes

---

## Local Testing

Before pushing to S3, test locally with a mock event:

```python
from lambda_function import lambda_handler
import json

with open("event.json") as f:
    event = json.load(f)

lambda_handler(event, {})
```

---

## Lambda Deployment with Environment Variables

Terraform sets environment variables for the Lambda function:

```hcl
environment {
  variables = {
    DB_SECRET_NAME = var.db_secret_name
  }
}
```

This allows the function to access DB credentials via `os.environ`.

---

## IAM Role and Permissions

The IAM policy allows scoped access for S3, Direct PyMySQL Connection, and Secrets Manager:

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

- **Direct PyMySQL Connection**: Rather than using the RDS Data API, the Lambda function connects directly to Aurora Serverless using the `pymysql` library. This allows full SQL flexibility and avoids limitations of the RDS Data API.
- **Currency Conversion Dictionary**: Maintained inside the Lambda function for transparency, simplicity, and ease of updating.
- **Secrets Manager Integration**: Secures database credentials and avoids hardcoding sensitive information.
- **Terraform Automation**: Enables reproducible, version-controlled infrastructure deployments.
- **Zip-Based Packaging**: External libraries like `pymysql` are bundled into the Lambda deployment package using a build script.

---

## Errors Encountered

### ❌ Lambda Not Updating via Terraform

One issue encountered during deployment was that code changes made to the Lambda function were not reflected in the AWS Console after running `terraform apply`. Terraform reported that there were “no changes,” even though the source code had clearly been updated.

This problem occurred because Terraform relies on a file hash to determine whether the deployment package has changed. Since this hash was not being tracked, the changes were ignored.

To resolve the issue, the `source_code_hash` attribute was added to the Lambda resource block in `lambda.tf` as follows:

```hcl
source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
```

After adding this line and re-running the deployment script (`bash deploy.sh`), Terraform correctly detected the code change and updated the Lambda function in AWS.

This fix ensured that any future changes to the deployment package would always trigger a redeployment.

---

### ❌ `No module named 'pymysql'`

Another issue encountered was a runtime error stating: `No module named 'pymysql'`. This occurred because the `pymysql` library was not included in the zipped deployment package.

To fix this, the required library was installed locally into a `build/` directory using the following command:

```bash
pip install pymysql -t build/
```

The `lambda_function.py` script was then placed inside the same `build/` directory. All files within that folder were zipped (excluding the folder itself) using:

```bash
cd build && zip -r ../terraform/lambda_function.zip .
```

After updating the deployment package, the function was redeployed using Terraform.

The Lambda function then executed successfully, confirming that the external dependency was correctly packaged and accessible at runtime.

---

## Skills Demonstrated

- AWS Lambda integration with Aurora Serverless via PyMySQL
- Python-based ETL pipeline with currency-aware logic
- Secrets Manager integration for secure credential handling
- Infrastructure-as-Code with Terraform
- Cloud debugging and deployment troubleshooting

---

## Conclusion

This project presents a secure and scalable solution for processing international billing data using a serverless architecture. It serves as a reusable and extensible framework for real-time financial data pipelines, highlighting best practices in cloud-native engineering, Python automation, and event-driven design.

---
