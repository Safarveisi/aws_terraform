resource "aws_iam_role" "example" {
  name = "examplerole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Service = [ "ec2.amazonaws.com" ] 
            }
            Action = "sts:AssumeRole"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "example" {
  role = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "example" {
  name = "example_profile"
  role = aws_iam_role.example.name
}

resource "aws_vpc" "example" {
  cidr_block = "${var.base_cidr}"
  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "example" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = cidrsubnet("${var.base_cidr}", 8, 0)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "example"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example"
  }
}

resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.example.id
  route_table_id = aws_route_table.example.id
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example"
  }
}

resource "aws_route" "example" {
  route_table_id         = aws_route_table.example.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.example.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.example.id]

  tags = {
    Name = "example"
  }
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = "*"
            Action = "*"
            Resource = "*"
        }
    ]
  })
}

resource "aws_security_group" "example" {
  name = "allow_traffic"
  description = "Allow ssh inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.example.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example"
  }
}

resource "aws_instance" "example" {
  ami = "ami-004e960cde33f9146"
  instance_type = "t2.micro" 
  key_name = "main-key"
  subnet_id = aws_subnet.example.id
  vpc_security_group_ids = [aws_security_group.example.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.example.name
  provisioner "file" {
    source = "customers-1.csv"
    destination = "/home/ubuntu/customers-1.csv"

    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = file("main-key.pem")
        host = self.public_ip
    }
  }
  user_data = filebase64("script.sh")
  tags = {
    Name = "example"
  }
}

resource "aws_s3_bucket_policy" "example" {
  bucket = "sajad-aws-s3-bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Deny"
            Principal = "*"
            Action = "s3:*"
            Resource = [
                "arn:aws:s3:::sajad-aws-s3-bucket",
                "arn:aws:s3:::sajad-aws-s3-bucket/*"
            ]
            Condition = {
                StringEquals = {
                    "aws:SourceVpce" = aws_vpc_endpoint.s3.id
                }
            }
        }
    ]
  })
}