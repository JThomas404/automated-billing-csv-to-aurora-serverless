output "vpc_id" {
  description = "ID of the VPC for Aurora Serverless."
  value       = aws_vpc.boto3_rds_vpc.id
}

output "s3_bucket_name_full" {
  description = "The final full S3 bucket name with random suffix"
  value       = aws_s3_bucket.boto3_billing_processed.bucket
}

output "db_subnet_group" {
  description = "Name of the DB subnet group used for Aurora."
  value       = aws_db_subnet_group.boto3_rds_subnet_group.name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.boto3_db_secret.arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.boto3_db_secret.name
}

output "aurora_endpoint" {
  description = "Cluster endpoint used to connect to the Aurora Serverless DB."
  value       = aws_rds_cluster.boto3_rds_cluster.endpoint
}
