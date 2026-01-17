# Dead-letter-queue for eventbridge
resource "aws_sqs_queue" "failed_invocations" {
  name = "eventbridge-ecs-dlq"
}