resource "aws_vpc" "boto3_rds_vpc" {
  cidr_block = "10.0.0.0/16"
  tags       = var.tags
}

resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.boto3_rds_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = var.tags
}

resource "aws_subnet" "private_subnet_1b" {
  vpc_id                  = aws_vpc.boto3_rds_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = var.tags
}

resource "aws_db_subnet_group" "boto3_rds_subnet_group" {
  name        = "boto3_rds_subnet_group"
  description = "Subnet group for Aurora Serverless."
  subnet_ids = [
    aws_subnet.private_subnet_1a.id,
    aws_subnet.private_subnet_1b.id
  ]
  tags = var.tags
}

resource "aws_rds_cluster" "boto3_rds_cluster" {
  cluster_identifier                  = var.rds_cluster_identifier
  engine                              = "aurora-mysql"
  engine_version                      = var.engine_version
  engine_mode                         = "provisioned"
  db_subnet_group_name                = aws_db_subnet_group.boto3_rds_subnet_group.name
  database_name                       = var.db_name
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  skip_final_snapshot                 = true

  master_username = var.db_master_username
  master_password = random_password.boto3_db_password.result

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "boto3_rds_instance" {
  identifier           = var.rds_instance_identifier
  cluster_identifier   = aws_rds_cluster.boto3_rds_cluster.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.boto3_rds_cluster.engine
  engine_version       = aws_rds_cluster.boto3_rds_cluster.engine_version
  db_subnet_group_name = aws_db_subnet_group.boto3_rds_subnet_group.name
  publicly_accessible  = false

  tags = var.tags
}

resource "aws_security_group" "aurora_sg" {
  name   = "aurora-db-sg"
  vpc_id = aws_vpc.boto3_rds_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
