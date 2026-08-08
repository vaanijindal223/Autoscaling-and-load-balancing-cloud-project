variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev/staging/prod) - used in tags"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "asproj"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# 3 AZs, one public + one private subnet each.
# Public subnets host the ALB and NAT Gateway.
# Private subnets host EC2 instances and ECS tasks (no direct internet inbound).
variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "app_port" {
  description = "Port your application listens on inside the container/instance"
  type        = number
  default     = 5000
}
