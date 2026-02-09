# ---------------------------
# Networking: VPC
# ---------------------------
resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# ---------------------------
# Internet Gateway (public subnets)
# ---------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# ---------------------------
# Public subnets (for NAT Gateway)
# ---------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# NAT Gateway (single-NAT pattern)
# ---------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags       = { Name = "${local.name_prefix}-nat" }
  depends_on = [aws_internet_gateway.this]
}

# ---------------------------
# Private subnets (ECS tasks run here)
# ---------------------------
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-private-${count.index + 1}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------
# ECS Cluster
# ---------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"
}

# ---------------------------
# Cloud Map namespace for Service Connect
# ---------------------------
resource "aws_service_discovery_private_dns_namespace" "ns" {
  name        = "demo.local"
  description = "Service Connect namespace"
  vpc         = aws_vpc.this.id
}

# ---------------------------
# IAM: execution role
# ---------------------------
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name_prefix}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------
# Logs
# - Service Connect proxy logs
# - App logs (backend/frontend)
# ----------------------------
resource "aws_cloudwatch_log_group" "sc" {
  name              = "/ecs/service-connect/${local.name_prefix}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/apps/${local.name_prefix}"
  retention_in_days = 14
}

# ---------------------------
# Security Groups
# ---------------------------
resource "aws_security_group" "frontend" {
  name   = "${local.name_prefix}-frontend-sg"
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-frontend-sg" }
}

resource "aws_security_group" "backend" {
  name   = "${local.name_prefix}-backend-sg"
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-backend-sg" }
}

# Backend allows inbound from frontend on 8080
resource "aws_security_group_rule" "backend_from_frontend" {
  type                     = "ingress"
  security_group_id        = aws_security_group.backend.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.frontend.id
}

# Egress open for demo (common for ECS services behind NAT)
resource "aws_security_group_rule" "frontend_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.frontend.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "backend_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.backend.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------
# Task Definition: backend
# - Actually listens on 8080
# - Port mapping has a NAME ("http") used by Service Connect
# ---------------------------
resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "public.ecr.aws/docker/library/python:3.11-slim"
      essential = true
      command   = ["python", "-m", "http.server", "8080"]

      portMappings = [
        { name = "http", containerPort = 8080, protocol = "tcp" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend"
        }
      }
    }
  ])
}

# ---------------------------
# Task Definition: frontend
# - Calls backend via Service Connect alias: http://backend:8080/
# ---------------------------
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "public.ecr.aws/m6o4g9r5/curlimages/curl:7.83.1"
      essential = true

      command = [
        "sh", "-lc",
        "sleep 10; while true; do echo '---'; date; curl -v --max-time 5 http://backend:8080/ | head -n 20; sleep 10; done"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])
}

# ---------------------------
# ECS Service: backend (Service Connect server)
# - Runs in private subnets
# - NO public IP
# ---------------------------
resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ns.arn

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.sc.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "sc-backend"
      }
    }

    service {
      port_name      = "http"
      discovery_name = "backend"

      client_alias {
        dns_name = "backend"
        port     = 8080
      }
    }
  }
}

# ---------------------------
# ECS Service: frontend (Service Connect client)
# - Runs in private subnets
# - NO public IP
# ---------------------------
resource "aws_ecs_service" "frontend" {
  name            = "${local.name_prefix}-frontend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ns.arn

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.sc.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "sc-frontend"
      }
    }
  }

  depends_on = [aws_ecs_service.backend]
}

resource "aws_cloudwatch_event_rule" "frontend_scale" {
  name        = "${local.name_prefix}-frontend-desiredcount-events"
  description = "When frontend desiredCount is updated, sync backend desiredCount"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"],
    source      = ["aws.ecs"],
    detail = {
      eventSource = ["ecs.amazonaws.com"],
      eventName   = ["UpdateService"],
      requestParameters = {
        cluster = [
          aws_ecs_cluster.this.arn,
          { prefix = aws_ecs_cluster.this.name }
        ],
        service = [
          aws_ecs_service.frontend.name,
          { prefix = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/" }
        ],
        desiredCount = [{ exists = true }]
      }
    }
  })
}

resource "aws_cloudwatch_log_group" "sync_backend_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.sync_backend.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "sync_backend" {
  # Source Code
  function_name    = "${local.name_prefix}-sync-backend-desiredcount"
  filename         = data.archive_file.sync_backend_zip.output_path
  source_code_hash = data.archive_file.sync_backend_zip.output_base64sha256
  runtime          = "python3.13"
  handler          = "sync_backend.lambda_handler"
  architectures    = ["x86_64"]

  # General
  memory_size = 128
  role        = aws_iam_role.sync_backend_role.arn
  timeout     = 30

  logging_config {
    log_format = "Text"
    log_group  = "/aws/lambda/${local.name_prefix}-sync-backend-desiredcount"
  }

  environment {
    variables = {
      CLUSTER_NAME          = aws_ecs_cluster.this.name
      FRONTEND_SERVICE_NAME = aws_ecs_service.frontend.name
      BACKEND_SERVICE_NAME  = aws_ecs_service.backend.name
    }
  }
}

resource "aws_cloudwatch_event_target" "invoke_sync_backend" {
  rule      = aws_cloudwatch_event_rule.frontend_scale.name
  target_id = "${local.name_prefix}-invoke-sync-backend"
  arn       = aws_lambda_function.sync_backend.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync_backend.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.frontend_scale.arn
}
