data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/main.zip"
}

resource "aws_lambda_function" "example" {
  filename         = data.archive_file.zip_the_python_code.output_path
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha512
  function_name    = "test-lambda-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.14"
  architectures    = ["x86_64"]

  logging_config {
    log_format = "Text"
    log_group  = "/aws/lambda/test-lambda-function"
  }

  vpc_config {
    subnet_ids         = [aws_subnet.this[0].id]
    security_group_ids = [aws_security_group.fastapi_caller.id]
  }
}

resource "aws_lambda_alias" "lambda_alias" {
  name             = "development"
  function_name    = aws_lambda_function.example.function_name
  function_version = aws_lambda_function.example.version
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.run_on_s3_put_object.name
  target_id = "example-lambda"
  arn       = aws_lambda_function.example.arn
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.run_on_s3_put_object.arn
}