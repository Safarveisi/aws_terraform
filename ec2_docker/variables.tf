variable "name_prefix" {
  description = "Prefix to be used in the name of the resources"
  type        = string
  default = "free"
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC, used for security group rules"
  type        = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnets_cidr_blocks" {
  description = "List of CIDR blocks for the subnets"
  type        = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}