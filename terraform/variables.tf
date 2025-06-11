variable "aws_region" {
  description = "The default AWS region for the project resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "boto3-rds-script"
    Environment = "Dev"
  }
}

variable "bucket_name_processed" {
  description = "Name of the S3 bucket for processed billing files."
  type        = string
}

variable "db_name" {
  description = "Name of the Aurora database schema."
  type        = string
}

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret to store DB credentials."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function for billing data processing."
  type        = string
}

variable "engine_version" {
  description = "Aurora MySQL engine version compatible with Serverless v2."
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "rds_cluster_identifier" {
  description = "Unique identifier for the RDS cluster."
  type        = string
  default     = "aurora-billing-cluster"
}

variable "rds_instance_identifier" {
  description = "Unique identifier for the RDS cluster instance."
  type        = string
  default     = "aurora-billing-instance"
}

variable "db_master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "admin"
}
