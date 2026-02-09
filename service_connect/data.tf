data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sync_backend_policy" {
  statement {
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "archive_file" "sync_backend_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/sync_backend.py"
  output_path = "${path.module}/lambda/sync_backend.zip"
}
