resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  tags                 = var.tags
  enable_dns_hostnames = true
}

resource "aws_subnet" "this" {
  count                   = length(var.subnets_cidr_blocks)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnets_cidr_blocks[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags                    = var.tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "this" {
  count          = length(var.subnets_cidr_blocks)
  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = aws_route_table.this.id
}

resource "aws_security_group" "fastapi_caller" {
  name        = "fastapi-caller-sg"
  description = "Security group for container instances"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.fastapi_caller.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

resource "aws_security_group" "fastapi_writer" {
  name        = "fastapi-writer-sg"
  description = "Security group for container instances"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.fastapi_caller.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}