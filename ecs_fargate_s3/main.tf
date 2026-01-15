resource "aws_ecs_cluster" "my_cluster" {
  name = "example-cluster"
}

resource "aws_ecs_task_definition" "scheduled_my_command" {
  family                   = "scheduled-my-command"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn = aws_iam_role.ecs_task.arn
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name      = "demo",
      image     = "docker.io/ciaa/fargate-s3:latest",
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
          awslogs-group         = "/ecs/my-scheduled-task-logs"
          awslogs-region        = "${var.aws_region}"
          awslogs-stream-prefix = "demo"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_event_target" "ecs_my_command_target" {
  rule      = aws_cloudwatch_event_rule.run_every_minute.name
  role_arn  = aws_iam_role.eventbridge_invoke_ecs.arn
  target_id = "ecs-task-my-command"
  arn = aws_ecs_cluster.my_cluster.arn
  ecs_target {
    task_definition_arn = aws_ecs_task_definition.scheduled_my_command.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = [aws_subnet.this[0].id]
      security_groups  = [aws_security_group.ecs_tasks.id]
      assign_public_ip = true
    }
  }
}