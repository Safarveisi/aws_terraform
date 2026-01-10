variable "aws_region" {
  type = string
  description = "AWS provider region can be found in your ~/.aws/config"
}

variable "base_cidr" {
  default = "10.0.0.0/16"
}