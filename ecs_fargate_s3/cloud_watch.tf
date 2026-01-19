data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

# Trigger the ECS task in Cluster 1 whenever an object is created in a S3 bucket
resource "aws_cloudwatch_event_rule" "run_on_s3_put_object" {
  name  = "s3-put-object"
  event_bus_name = data.aws_cloudwatch_event_bus.default.name

  event_pattern = jsonencode({
    source = ["aws.s3"],
    detail-type = ["Object Created"],
    detail = {
      bucket = {
        name = ["sajad-aws-s3-bucket-2"]
      }
    }
  })
}

resource "aws_cloudwatch_log_group" "caller" {
  name              = "/ecs/caller-logs"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "fastapi" {
  name              = "/ecs/fastapi-writer-logs"
  retention_in_days = 1
}