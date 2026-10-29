variable "public_subnets" {
  description = "A map of public subnets with their CIDR blocks"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  default = {
    "public_subnet_az1_cidr" = {
      cidr_block        = "10.0.0.0/24"
      availability_zone = "us-east-1a"
    }

    "public_subnet_az2_cidr" = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "private_subnets" {
  description = "A map of private subnets with their CIDR blocks"
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  default = {
    "private_app_subnet_az1_cidr" = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
    }

    "private_app_subnet_az2_cidr" = {
      cidr_block        = "10.0.11.0/24"
      availability_zone = "us-east-1b"
    }

    "private_db_subnet_az1_cidr" = {
      cidr_block        = "10.0.20.0/24"
      availability_zone = "us-east-1a"
    }

    "private_db_subnet_az2_cidr" = {
      cidr_block        = "10.0.21.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "var_region" {
  description = "The AWS region to deply resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block of the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}