resource "aws_cloudwatch_event_rule" "run_every_minute" {
  name                = "run-ecs-task-every-minute"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_log_group" "caller" {
  name              = "/ecs/caller-logs"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "fastapi" {
  name              = "/ecs/fastapi-writer-logs"
  retention_in_days = 1
}