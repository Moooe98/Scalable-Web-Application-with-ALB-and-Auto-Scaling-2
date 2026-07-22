################################################################################
# RDS Module — MySQL 8.0 Multi-AZ
################################################################################

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "RDS subnet group for ${var.project_name}"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-mysql8"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL 8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql8-params"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-rds"
  engine            = "mysql"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  # Multi-AZ for automatic failover
  # NOTE: Set to false for free-tier accounts; set to true for production paid accounts
  multi_az = false

  # Automated backups (0 = disabled for free tier; set to 7 for paid accounts)
  backup_retention_period = 0
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Enhanced monitoring (disabled for free tier)
  monitoring_interval = 0

  # Performance insights (disabled for free tier)
  performance_insights_enabled = false

  deletion_protection = false
  skip_final_snapshot = true

  auto_minor_version_upgrade = true
  publicly_accessible        = false

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

# Enhanced monitoring IAM role — disabled for free-tier accounts
# Uncomment and set monitoring_interval=60 + monitoring_role_arn for paid accounts

