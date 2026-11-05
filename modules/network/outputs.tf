output "vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet_ids" {
    value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_app_subnet_ids" {
    value = [
        for key, subnet in aws_subnet.private : subnet.id
        if contains(["private_app_subnet_az1_cidr", "private_app_subnet_az2_cidr"], key)
    ]
}

output "private_db_subnet_ids" {
    value = [
        for key, subnet in aws_subnet.private : subnet.id
        if contains(["private_db_subnet_az1_cidr", "private_db_subnet_az2_cidr"], key)
    ]
}

output "alb_sg_id" {
    value = aws_security_group.alb.id
}

output "ec2_sg_id" {
    value = aws_security_group.ec2.id
}

output "rds_sg_id" {
    value = aws_security_group.rds.id
}