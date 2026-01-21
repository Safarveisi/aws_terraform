# Cluster 1
resource "aws_ecs_cluster" "caller" {
  name = "caller-cluster"
}

# Cluster 2
resource "aws_ecs_cluster" "fastapi" {
  name = "fastapi-cluster"
}

# Task 1 - cluster 1
resource "aws_ecs_task_definition" "caller" {
  family                   = "fastapi-caller"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.ecs_task.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "demo",
      image     = "docker.io/ciaa/caller:latest",
      essential = true,
      secrets = [
        {
          name      = "DOCKER_USERNAME",
          valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.id}:parameter/docker/username"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/caller-logs"
          awslogs-region        = "${var.aws_region}"
          awslogs-stream-prefix = "demo"
        }
      }
    }
  ])
}

# Setup scheduling for Task 1
resource "aws_cloudwatch_event_target" "ecs_my_command_target" {
  rule      = aws_cloudwatch_event_rule.run_on_s3_put_object.name
  role_arn  = aws_iam_role.eventbridge_invoke_ecs.arn
  target_id = "ecs-task-my-command"
  arn       = aws_ecs_cluster.caller.arn
  ecs_target {
    task_definition_arn = aws_ecs_task_definition.caller.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = [aws_subnet.this[0].id]
      security_groups  = [aws_security_group.fastapi_caller.id]
      assign_public_ip = true
    }
  }

  # This is only needed for debugging (failed invocations)
  dead_letter_config {
    arn = aws_sqs_queue.failed_invocations.arn
  }

  depends_on = [aws_ecs_service.fastapi]
}

# Task 2 - cluster 2
resource "aws_ecs_task_definition" "fastapi" {
  family                   = "fastapi-writer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "fastapi-writer"
      image     = "docker.io/ciaa/callee:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"

        }
      ]

      environment = [
        { name = "BUCKET_NAME", value = var.bucket_name },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/fastapi-writer-logs"
          awslogs-region        = "${var.aws_region}"
          awslogs-stream-prefix = "demo"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8000/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

# Service - Cluster 2
resource "aws_ecs_service" "fastapi" {
  name                  = "fastapi-writer-svc"
  cluster               = aws_ecs_cluster.fastapi.id
  task_definition       = aws_ecs_task_definition.fastapi.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  wait_for_steady_state = true
  force_new_deployment  = true

  network_configuration {
    subnets          = [aws_subnet.this[1].id]
    security_groups  = [aws_security_group.fastapi_writer.id]
    assign_public_ip = true
  }

  # Register tasks in Cloud Map (service discovery)
  service_registries {
    container_name = "fastapi-writer"
    registry_arn   = aws_service_discovery_service.fastapi_writer.arn
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

}