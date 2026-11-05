resource "aws_db_subnet_group" "main" {
  name        = "main-database-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "Main-DB-Subnet-Group"
  }
}


# RDS Database Tier

# Password Management
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name_prefix = "main-app-database-credentails-"
  description = "Master credentials for the main RDS database"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
  })
}

# RDS

resource "aws_db_instance" "main" {
  identifier = "main-app-database"

  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "app_database"
  username = "dbadmin"

  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  multi_az = true

  # Setting this to true to avoid incuring storage costs. But it should be set to false in prod.
  skip_final_snapshot = true

  tags = {
    Name = "Main-Database-HA"
  }

}