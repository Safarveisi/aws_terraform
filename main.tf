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
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "example" {
  name = "example_profile"
  role = aws_iam_role.example.name
}

resource "aws_vpc" "sample" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "sample" {
  vpc_id            = aws_vpc.sample.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "example"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.sample.id

  tags = {
    Name = "example"
  }
}

resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.sample.id
  route_table_id = aws_route_table.example.id
}

resource "aws_internet_gateway" "sample" {
  vpc_id = aws_vpc.sample.id

  tags = {
    Name = "example"
  }
}

resource "aws_route" "example" {
  route_table_id         = aws_route_table.example.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample.id
}


resource "aws_security_group" "example" {
  name = "allow_traffic"
  description = "Allow ssh inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.sample.id

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
  subnet_id = aws_subnet.sample.id
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
  tags = {
    Name = "example"
  }
}

resource "aws_s3_bucket_policy" "example_bucket_policy" {
  bucket = "sajad-aws-s3-bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow",
            Principal = {
                AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.example.name}"
            }
            Action = [
                "s3:GetObject",
                "s3:ListBucket"
            ]
            Resource = [
                "arn:aws:s3:::sajad-aws-s3-bucket",
                "arn:aws:s3:::sajad-aws-s3-bucket/*"
            ]
        }
    ]
  })
}