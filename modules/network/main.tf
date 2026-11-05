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
