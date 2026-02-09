resource "aws_iam_role" "sync_backend_role" {
  name               = "${local.name_prefix}-sync-backend-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "sync_backend_policy" {
  name   = "${local.name_prefix}-sync-backend-policy"
  role   = aws_iam_role.sync_backend_role.id
  policy = data.aws_iam_policy_document.sync_backend_policy.json
}
