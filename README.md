# Automated Billing CSV to Aurora Serverless

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [Core Implementation Breakdown](#core-implementation-breakdown)
- [Local Testing and Debugging](#local-testing-and-debugging)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered and Resolved](#errors-encountered-and-resolved)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless ETL pipeline that processes international billing data through event-driven architecture. When CSV files containing billing records are uploaded to an S3 bucket, a Lambda function automatically triggers to read, transform, and load the data into an Aurora Serverless V2 MySQL database. The solution handles multi-currency billing data by converting all amounts to USD using predefined exchange rates, ensuring consistent financial reporting across international transactions.

The architecture leverages AWS managed services including Lambda, S3, Aurora Serverless V2, Secrets Manager, and RDS Data API to create a scalable, secure, and cost-effective data processing pipeline.

---

## Real-World Business Value

This automation addresses critical challenges faced by finance and data engineering teams managing international billing operations:

- **Eliminates Manual Processing**: Removes the need for manual CSV uploads and currency conversions, reducing processing time from hours to seconds
- **Ensures Data Consistency**: Standardises all billing amounts to USD, preventing currency-related reporting discrepancies
- **Provides Real-Time Processing**: Event-driven architecture enables immediate data availability for downstream analytics and reporting systems
- **Reduces Operational Risk**: Automated validation and error handling minimise data quality issues and processing failures
- **Scales Automatically**: Serverless architecture handles varying data volumes without infrastructure management overhead

The solution provides a production-ready framework for financial data ingestion that can be extended to support additional currencies, validation rules, and data transformations.

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform CLI (>= 1.3.0) installed
- Python 3.11 runtime environment
- Aurora Serverless V2 cluster with MySQL 8.0 compatibility
- AWS Secrets Manager for secure credential storage
- S3 bucket with event notification configuration

---

## Project Folder Structure

```
automated-billing-csv-to-aurora-serverless-1/
├── lambda/
│   ├── event.json                          # Sample S3 event for local testing
│   └── lambda_function.py                  # Core Lambda processing logic
├── s3_files/                               # Sample billing CSV files
│   ├── billing_data_bakery_june_2025.csv
│   ├── billing_data_dairy_june_2025.csv
│   └── billing_data_meat_june_2025.csv
├── terraform/                              # Infrastructure as Code
│   ├── iam.tf                              # IAM roles and policies
│   ├── lambda.tf                           # Lambda function configuration
│   ├── main.tf                             # Provider and version constraints
│   ├── outputs.tf                          # Terraform outputs
│   ├── rds.tf                              # Aurora Serverless V2 cluster
│   ├── s3.tf                               # S3 bucket configuration
│   ├── secrets.tf                          # Secrets Manager setup
│   ├── terraform.tfvars                    # Variable values
│   └── variables.tf                        # Variable definitions
├── deploy.sh                               # Automated deployment script
├── requirements.txt                        # Python dependencies
└── README.md                               # Project documentation
```

---

## Core Implementation Breakdown

### Lambda Function Architecture

The [lambda_function.py](lambda/lambda_function.py) implements a modular processing pipeline:

#### Currency Conversion Logic

```python
currency_conversion_to_usd = {
    'USD': 1,
    'CAD': 0.79,
    'MXN': 0.05
}
```

#### RDS Data API Integration

```python
def execute_statement(sql, sql_parameters):
    return rds_client.execute_statement(
        secretArn=secrets_store_arn,
        database=database_name,
        resourceArn=db_cluster_arn,
        sql=sql,
        parameters=sql_parameters
    )
```

#### Record Processing Function

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
```

### Infrastructure Components

#### Aurora Serverless V2 Configuration

The [rds.tf](terraform/rds.tf) implements:

- **Serverless V2 Scaling**: Automatic capacity adjustment between 0.5-2 ACUs
- **Multi-AZ Deployment**: High availability across us-east-1a and us-east-1b
- **Encryption**: Storage encryption enabled with AWS managed keys
- **Network Security**: VPC isolation with MySQL port 3306 restricted to internal traffic

#### IAM Security Model

The [iam.tf](terraform/iam.tf) enforces least privilege access:

- **S3 Permissions**: GetObject and ListBucket limited to the specific billing bucket
- **RDS Data API**: Execute statement permissions for the Aurora cluster
- **Secrets Manager**: GetSecretValue access restricted to the database secret
- **CloudWatch Logs**: Standard Lambda logging permissions

---

## Local Testing and Debugging

### Mock Event Testing

Local validation uses the sample event structure in [event.json](lambda/event.json):

```python
from lambda_function import lambda_handler
import json

with open("event.json") as f:
    event = json.load(f)

lambda_handler(event, {})
```

### CSV Data Validation

Sample billing files in [s3_files/](s3_files/) contain realistic test data with:

- **Multi-Currency Records**: USD, CAD, and MXN billing amounts
- **Data Quality Issues**: Invalid currency codes for error handling validation
- **Negative Amounts**: Credit transactions and refund scenarios
- **Large Values**: High-volume transaction testing

### CloudWatch Monitoring

The Lambda function implements structured logging for operational visibility:

- **Event Processing**: Complete S3 event details logged for audit trails
- **Currency Conversion**: Exchange rate application and USD calculation logging
- **Database Operations**: SQL execution responses and error conditions
- **Performance Metrics**: Processing duration and record count tracking

---

## IAM Role and Permissions

The security model implements least privilege access through targeted IAM policies:

### Lambda Execution Role

```hcl
resource "aws_iam_role" "BillingLambdaExecutionRole" {
  name = "BillingLambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
```

### Scoped Permissions Policy

The inline policy grants specific access to:

- **S3 Operations**: GetObject and ListBucket for the billing data bucket only
- **RDS Data API**: ExecuteStatement permission for Aurora Serverless interaction
- **Secrets Manager**: GetSecretValue access limited to the database credential secret
- **CloudWatch Logs**: Standard Lambda logging capabilities for operational monitoring

This approach ensures the Lambda function cannot access resources outside its operational requirements, maintaining security boundaries whilst enabling full functionality.

---

## Design Decisions and Highlights

### RDS Data API Selection

The implementation uses AWS RDS Data API rather than direct database connections for several strategic reasons:

- **Serverless Compatibility**: Eliminates connection pooling complexity in Lambda environments
- **Automatic Credential Management**: Seamless integration with Secrets Manager for secure authentication
- **Simplified Networking**: Removes VPC configuration requirements for Lambda functions
- **Built-in Retry Logic**: AWS-managed connection resilience and error handling

### Currency Conversion Strategy

Exchange rates are maintained within the Lambda function code rather than external services:

- **Predictable Performance**: Eliminates external API dependencies and potential latency issues
- **Cost Optimisation**: Avoids third-party service charges for currency conversion
- **Simplified Deployment**: Reduces infrastructure complexity and external service management
- **Controlled Updates**: Exchange rates updated through code deployment cycles for audit trails

### Aurora Serverless V2 Architecture

The database implementation leverages Aurora Serverless V2 for optimal cost and performance:

- **Automatic Scaling**: Capacity adjusts from 0.5 to 2 ACUs based on workload demands
- **Cost Efficiency**: Pay-per-use pricing model aligns with intermittent ETL processing patterns
- **High Availability**: Multi-AZ deployment ensures business continuity
- **MySQL Compatibility**: Familiar SQL interface with enterprise-grade features

### Terraform State Management

Infrastructure deployment uses local state management with considerations for production scaling:

- **Version Control**: Terraform configurations tracked in Git for change management
- **Modular Design**: Separate resource files enable targeted updates and maintenance
- **Variable Parameterisation**: Environment-specific values isolated in terraform.tfvars

---

## Errors Encountered and Resolved

### Lambda Deployment Hash Mismatch

**Issue**: Terraform failed to detect Lambda function code changes, resulting in outdated deployments despite source code modifications.

**Root Cause**: Missing source_code_hash attribute in the Lambda resource configuration prevented Terraform from recognising deployment package changes.

**Resolution**: Added filebase64sha256 hash calculation to the Lambda resource:

```hcl
resource "aws_lambda_function" "BillingProcessorLambda" {
  filename         = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  # ... other configuration
}
```

**Impact**: Ensured reliable deployment automation and eliminated manual intervention requirements for code updates.

### RDS Data API Parameter Binding

**Issue**: Initial SQL queries failed with parameter binding errors when using direct string interpolation.

**Root Cause**: RDS Data API requires specific parameter format with typed values rather than string substitution.

**Resolution**: Implemented parameterised queries with proper type specification:

```python
sql_parameters = [
    {'name': 'bill_amount', 'value': {'doubleValue': bill_amount}},
    {'name': 'company_name', 'value': {'stringValue': company_name}},
    # ... additional parameters
]
```

**Impact**: Eliminated SQL injection vulnerabilities whilst ensuring proper data type handling in Aurora Serverless.

---

## Skills Demonstrated

### Cloud Architecture and Services

- **AWS Lambda**: Serverless function development with Python 3.11 runtime
- **Aurora Serverless V2**: MySQL database implementation with automatic scaling
- **RDS Data API**: Serverless database connectivity and SQL execution
- **AWS Secrets Manager**: Secure credential storage and retrieval
- **Amazon S3**: Event-driven file processing and storage management

### Infrastructure as Code

- **Terraform**: Complete infrastructure provisioning with AWS Provider 5.0
- **Modular Configuration**: Separated resource definitions for maintainability
- **Variable Management**: Parameterised deployments for environment flexibility
- **State Management**: Local state handling with deployment automation

### Security Implementation

- **IAM Least Privilege**: Scoped permissions for service-to-service communication
- **Encryption at Rest**: Aurora cluster data protection
- **Secure Credential Handling**: Secrets Manager integration for database authentication
- **Network Security**: VPC isolation and security group configuration

### Software Engineering

- **Event-Driven Architecture**: S3 trigger-based processing pipeline
- **Error Handling**: Comprehensive exception management and logging
- **Data Transformation**: Multi-currency conversion with validation logic
- **Automated Deployment**: Bash scripting for CI/CD pipeline integration

---

## Conclusion

This project demonstrates the implementation of a production-ready serverless ETL pipeline that addresses real-world financial data processing requirements. The solution combines AWS managed services to create a scalable, secure, and cost-effective architecture for international billing data ingestion.

Key achievements include the successful integration of Aurora Serverless V2 with Lambda functions through RDS Data API, implementation of comprehensive security controls through IAM and Secrets Manager, and creation of automated deployment processes using Terraform and shell scripting.

The architecture provides a foundation for extending financial data processing capabilities, including additional currency support, enhanced validation rules, and integration with downstream analytics platforms. The modular design and Infrastructure as Code approach ensure maintainability and reproducibility across development and production environments.
