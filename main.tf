terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "three-tier-web-platform-terraform-state-bucket-mihiringole"
    key          = "global/s3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.var_region

  default_tags {
    tags = {
      Environment = "Dev"
      Project     = "Resume"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

#Public Subnet
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = each.key
  }
}

#Private Subnet
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.key
  }
}

# Internet Gateway (IGW)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

#Elastic IP
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "NAT-EIP" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  #Placing a single NAT Gateway into the first subnet. (Not placing into both subnets due to high cost for personal project compromising HA.)
  subnet_id = values(aws_subnet.public)[0].id

  # Ensuring the internet gateway exists before NAT GW.
  depends_on = [aws_internet_gateway.main]
  tags       = { Name = "Main-NAT" }
}


#Public subnet route table 

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}


#Private subnet route table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "public_subnet" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

locals {
  nat_associated_subnets = ["private_app_subnet_az1_cidr", "private_app_subnet_az2_cidr"]
}

resource "aws_route_table_association" "private_subnet" {

  for_each = {
    for key, subnet in aws_subnet.private : key => subnet
    if contains(local.nat_associated_subnets, key)
  }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}



# Security Groups

resource "aws_security_group" "alb" {
  name        = "alb-security-group"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "ec2" {
  name        = "ec2-security-group"
  description = "Security group for the EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-security-group"
  description = "Security group for the RDS database"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "rds-sg"
  }
}

# Application Load Balancer (ALB) Security Group Rules

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow inbound HTTP traffic from anywhere"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow inbound HTTPS traffic from anywhere"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Forward traffic to EC2 instances"
}

# EC2 Security Group rules

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow inbound HTTP strictly from ALB security group"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

# RDS Security Group

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL access strictly from EC2 security group"
}


# Load Balancer components

resource "aws_lb" "main" {
  name               = "main-aws-lb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  subnets = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = {
    Name = "Main-ALB"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = {
    Name = "App-Target-Group"
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "app-launch-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Deployed via Terraform Launch Template</h1>" > /var/www/html/index.html
              EOF
  )

  update_default_version = true

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "App-Server"
    }
  }
}


resource "aws_autoscaling_group" "app" {
  name_prefix = "app-asg-"

  vpc_zone_identifier = [
    for key, subnet in aws_subnet.private : subnet.id
    if contains(local.nat_associated_subnets, key)
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "App-Server-ASG"
    propagate_at_launch = true
  }
}


locals {
  db_associated_subnets = ["private_db_subnet_az1_cidr", "private_db_subnet_az2_cidr"]
}

resource "aws_db_subnet_group" "main" {
  name        = "main-database-subnet-group"
  description = "Subnet group for RDS instance"

  subnet_ids = [
    for key, subnet in aws_subnet.private : subnet.id
    if contains(local.db_associated_subnets, key)
  ]

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
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "app_database"
  username = "dbadmin"

  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az = true

  # Setting this to true to avoid incuring storage costs. But it should be set to false in prod.
  skip_final_snapshot = true

  tags = {
    Name = "Main-Database-HA"
  }

}