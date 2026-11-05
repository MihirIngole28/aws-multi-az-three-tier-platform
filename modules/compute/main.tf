# Load Balancer components

resource "aws_lb" "main" {
  name               = "main-aws-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [var.alb_sg_id]
  subnets = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "Main-ALB"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
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

  vpc_security_group_ids = [var.ec2_sg_id]

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

  vpc_zone_identifier = var.private_app_subnet_ids

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
