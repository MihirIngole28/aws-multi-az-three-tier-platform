variable "private_db_subnet_ids" {
  description = "List of private subnet IDs for the RDS database"
  type = list(string)
}

variable "rds_sg_id" {
    description = "Security Group ID for the RDS database"
    type = string
}