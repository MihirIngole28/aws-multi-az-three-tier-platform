variable "vpc_id" {
    description = "The ID of the VPC"
    type = string
}

variable "public_subnet_ids" {
    description = "List of public subnet IDs for the ALB"
    type = list(string)
}

variable "private_app_subnet_ids" {
    description = "List of private subnet IDs or the EC2 Auto Scaling Group"
    type = list(string)
}

variable "alb_sg_id" {
    description = "Security Group ID for the ALB"
    type = string
}

variable "ec2_sg_id" {
    description = "Security Group ID for the EC2 instances"
    type = string
}