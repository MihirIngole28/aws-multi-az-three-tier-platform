variable "vpc_cidr" {
    description = "The CIDR block of the main VPC"
    type = string
}

variable "public_subnets" {
    description = "A map of public subnets with their CIDR blocks"
    type = map(object({
        cidr_block = string
        availability_zone = string
    }))
}

variable "private_subnets" {
    description = "A map of private subnets with their CIDR blocks"
    type = map(object({
        cidr_block = string
        availability_zone = string
    }))
  
}