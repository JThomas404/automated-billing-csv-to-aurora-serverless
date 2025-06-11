resource "aws_lambda_function" "BillingProcessorLambda" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.BillingLambdaExecutionRole.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  timeout          = 30

  environment {
    variables = {
      DB_SECRET_NAME = var.db_secret_name
    }
  }

  tags = var.tags
}
