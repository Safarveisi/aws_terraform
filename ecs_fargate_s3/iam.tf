# Role your ECS cluster needs to spin up container instances (e.g., getting docker images or ssm parameters)
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name = "${local.name_prefix}-task-execution-ssm"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/c028cd8f-4a67-42ae-9054-bdf6c7999fde",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/docker/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_foundational" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution.name
}

# Role your ECS cluster's instances need during run time (e.g., access to a S3 bucket)
resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_doc.json
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${local.name_prefix}-task-s3"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# Role your event bridge needs to trigger an ECS cluster's task
resource "aws_iam_role" "eventbridge_invoke_ecs" {
  name = "eventbridge-ecs-invoke-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      },
      Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_ecs_policy" {
  name = "invoke-ecs"
  role = aws_iam_role.eventbridge_invoke_ecs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ecs:RunTask",
        Resource = aws_ecs_task_definition.caller.arn
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          aws_iam_role.ecs_task.arn,
          aws_iam_role.ecs_task_execution.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = "ecs:RunTask",
        Resource = "*",
        Condition = {
          "ArnEquals" : {
            "ecs:cluster" : aws_ecs_cluster.caller.arn
          }
        }
      }
    ]
  })
}

# Role your SQS queue needs to notify failed invocations (eventbridge)
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = aws_sqs_queue.failed_invocations.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEventBridgeToSendMessages",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.failed_invocations.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.run_on_s3_put_object.arn
          }
        }
      }
    ]
  })
}