resource "random_password" "boto3_db_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:;,.<>?|~"
}


resource "aws_secretsmanager_secret" "boto3_db_secret" {
  name = var.db_secret_name
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "boto3_db_secret_version" {
  secret_id = aws_secretsmanager_secret.boto3_db_secret.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.boto3_db_password.result
    host     = aws_rds_cluster.boto3_rds_cluster.endpoint
    port     = 3306
    dbname   = var.db_name
  })

  depends_on = [aws_rds_cluster.boto3_rds_cluster]
}
