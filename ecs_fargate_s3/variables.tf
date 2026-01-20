variable "aws_region" {
  description = "AWS region where the resources are deployed"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC, used for security group rules"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets_cidr_blocks" {
  description = "List of CIDR blocks for the subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "bucket_name" {
  description = "S3 bucket accessible from ECS container instances"
  type        = string
  default     = "sajad-aws-s3-bucket"
}