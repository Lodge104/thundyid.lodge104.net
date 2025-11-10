# Aurora Serverless v2 PostgreSQL Database with Lightsail VPC Peering Support
# 
# This configuration creates a cost-optimized Aurora Serverless v2 PostgreSQL database
# that can be accessed from Amazon Lightsail container services via VPC Peering.
#
# Prerequisites:
# 1. VPC Peering must be enabled for Lightsail in your AWS region
# 2. See: https://docs.aws.amazon.com/lightsail/latest/userguide/lightsail-how-to-set-up-vpc-peering-with-aws-resources.html
#
# Benefits of VPC Peering vs Public Access:
# - More secure (no public internet exposure)
# - Lower latency
# - No data transfer charges between Lightsail and VPC
# - Database remains in private subnets

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate a random password for the database using openssl
resource "null_resource" "authentik_db_password" {
  triggers = {
    rotate = timestamp()
  }
  
  provisioner "local-exec" {
    command = "openssl rand -base64 36 | tr -d '\n' | tr -d '/\"@ ' > ${path.module}/.db_password"
  }
}

data "local_file" "authentik_db_password" {
  filename = "${path.module}/.db_password"
  depends_on = [null_resource.authentik_db_password]
}

# Get default VPC and subnets to minimize costs
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# DB subnet group using default VPC subnets (accessible via VPC Peering)
resource "aws_db_subnet_group" "authentik_subnet_group" {
  name       = "authentik-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "authentik DB subnet group"
    Environment = var.environment
    Project     = "authentik"
  }
}

# Security group for Aurora cluster
resource "aws_security_group" "authentik_aurora_sg" {
  name_prefix = "authentik-aurora-sg"
  vpc_id      = data.aws_vpc.default.id

  # Allow access from VPC
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "PostgreSQL access from VPC"
  }

  # Conditional access for Lightsail container services via VPC Peering
  dynamic "ingress" {
    for_each = var.allow_lightsail_access ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.lightsail_cidr_blocks
      description = "PostgreSQL access from Amazon Lightsail container services via VPC Peering"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "authentik Aurora Security Group"
    Environment = var.environment
    Project     = "authentik"
  }
}

# Aurora cluster parameter group for PostgreSQL
resource "aws_rds_cluster_parameter_group" "authentik_cluster_pg" {
  family = "aurora-postgresql15"
  name   = "authentik-cluster-pg"

  # Cost optimization parameters
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = {
    Name        = "authentik Cluster Parameter Group"
    Environment = var.environment
    Project     = "authentik"
  }
}

# Aurora Serverless v2 cluster
resource "aws_rds_cluster" "authentik_cluster" {
  cluster_identifier = "authentik-aurora-cluster"
  engine             = "aurora-postgresql"
  engine_version     = "15.13"
  database_name      = "authentik"
  master_username    = var.db_username
  master_password    = data.local_file.authentik_db_password.content

  # Cost optimization settings
  backup_retention_period      = 1 # Minimum backup retention (1 day)
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Serverless v2 scaling configuration - minimum for cost optimization
  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  # Network and security
  db_subnet_group_name            = aws_db_subnet_group.authentik_subnet_group.name
  vpc_security_group_ids          = [aws_security_group.authentik_aurora_sg.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.authentik_cluster_pg.name

  # Security settings
  storage_encrypted     = true           # Enable encryption at rest for security
  kms_key_id            = var.kms_key_id # Use custom KMS key or AWS managed key
  copy_tags_to_snapshot = true
  deletion_protection   = true # Allow deletion to avoid accidental costs
  skip_final_snapshot   = true # Skip final snapshot for cost savings

  # Performance Insights disabled to save costs
  enabled_cloudwatch_logs_exports = []

  tags = {
    Name        = "authentik Aurora Cluster"
    Environment = var.environment
    Project     = "authentik"
  }
}

# Aurora Serverless v2 instance
resource "aws_rds_cluster_instance" "authentik_instance" {
  identifier         = "authentik-aurora-instance"
  cluster_identifier = aws_rds_cluster.authentik_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.authentik_cluster.engine
  engine_version     = aws_rds_cluster.authentik_cluster.engine_version

  # Make publicly accessible for Lightsail container services
  publicly_accessible = var.publicly_accessible

  # Cost optimization - disable monitoring
  monitoring_interval = 0

  # Performance Insights disabled
  performance_insights_enabled = false

  tags = {
    Name        = "authentik Aurora Instance"
    Environment = var.environment
    Project     = "authentik"
  }
}

# Store password in AWS Systems Manager Parameter Store (secure and free)
resource "aws_ssm_parameter" "authentik_db_password" {
  name  = "/authentik/database/password"
  type  = "SecureString"
  value = data.local_file.authentik_db_password.content

  tags = {
    Name        = "authentik Database Password"
    Environment = var.environment
    Project     = "authentik"
  }
}
