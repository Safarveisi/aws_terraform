resource "aws_sqs_queue" "failed_invocations" {
  name = "eventbridge-ecs-dlq"
}

resource "aws_cloudwatch_event_rule" "run_every_minute" {
  name                = "run-ecs-task-every-minute"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_log_group" "my_scheduled_task" {
  name              = "/ecs/my-scheduled-task-logs"
  retention_in_days = 1
}