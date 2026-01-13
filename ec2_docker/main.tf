resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
  tags       = var.tags
}

resource "aws_subnet" "this" {
  count = length(var.subnets_cidr_blocks)
  vpc_id     = aws_vpc.this.id
  cidr_block = var.subnets_cidr_blocks[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags       = var.tags
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

resource "aws_security_group" "instance_sg" {
  name        = "${var.name_prefix}-instance-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = -1
  from_port = 0
  to_port   = 0
  description = "Allow all outbound traffic"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port       = 22
  to_port         = 22
  ip_protocol = "tcp"
  description = "Allow SSH access"
}

resource "aws_instance" "docker_host" {
  ami           = data.aws_ssm_parameter.ubuntu_22_04_ami.value
  instance_type = var.instance_type
  subnet_id     = element(aws_subnet.this.*.id, 0)
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  monitoring = true
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-docker-host"
    }
  )

  root_block_device {
    encrypted = true
    volume_size = 400
    volume_type = "gp2"
    delete_on_termination = true
    tags = merge(tomap({
        Name = "${var.name_prefix}-docker-host"}),
    var.tags)
  }
  
  user_data = file("${path.module}/files/user_data.sh")

 lifecycle {
   ignore_changes = [ ami ]
 }
}