/*resource "aws_lambda_permission" "atlantis_approval_dev" {
  statement_id  = "AllowExecutionFromCodeCommitDev"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atlantis.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.atlantis_approval_dev.arn
}

resource "aws_lambda_permission" "atlantis_approval_qa" {
  statement_id  = "AllowExecutionFromCodeCommitQA"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atlantis.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.atlantis_approval_qa.arn
}

resource "aws_lambda_permission" "atlantis_approval_prod" {
  statement_id  = "AllowExecutionFromCodeCommitProd"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atlantis.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.atlantis_approval_prod.arn
}

resource "aws_sns_topic" "atlantis_approval_dev" {
  name = "atlantis-approval-dev"
}

resource "aws_sns_topic" "atlantis_approval_qa" {
  name = "atlantis-approval-qa"
}

resource "aws_sns_topic" "atlantis_approval_prod" {
  name = "atlantis-approval-prod"
}

resource "aws_sns_topic_subscription" "atlantis_approval_dev" {
  topic_arn = aws_sns_topic.atlantis_approval_dev.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.atlantis.arn
}

resource "aws_sns_topic_subscription" "atlantis_approval_qa" {
  topic_arn = aws_sns_topic.atlantis_approval_qa.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.atlantis.arn
}

resource "aws_sns_topic_subscription" "atlantis_approval_prod" {
  topic_arn = aws_sns_topic.atlantis_approval_prod.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.atlantis.arn
}

resource "aws_sns_topic_policy" "atlantis_approval_dev" {
  arn = aws_sns_topic.atlantis_approval_dev.arn

  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "policy-for-atlantis-approval-dev",
    Statement = [
      {
        Sid    = "AllowLambdaToSubscribe",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action   = "SNS:Subscribe",
        Resource = aws_sns_topic.atlantis_approval_dev.arn
      },
      {
        Sid    = "AllowSnsToInvokeLambda",
        Effect = "Allow",
        Principal = {
          Service = "sns.amazonaws.com"
        },
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.atlantis.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "atlantis_approval_qa" {
  arn = aws_sns_topic.atlantis_approval_qa.arn

  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "policy-for-atlantis-approval-qa",
    Statement = [
      {
        Sid    = "AllowLambdaToSubscribe",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action   = "SNS:Subscribe",
        Resource = aws_sns_topic.atlantis_approval_qa.arn
      },
      {
        Sid    = "AllowSnsToInvokeLambda",
        Effect = "Allow",
        Principal = {
          Service = "sns.amazonaws.com"
        },
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.atlantis.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "atlantis_approval_prod" {
  arn = aws_sns_topic.atlantis_approval_prod.arn

  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "policy-for-atlantis-approval-prod",
    Statement = [
      {
        Sid    = "AllowLambdaToSubscribe",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action   = "SNS:Subscribe",
        Resource = aws_sns_topic.atlantis_approval_prod.arn
      },
      {
        Sid    = "AllowSnsToInvokeLambda",
        Effect = "Allow",
        Principal = {
          Service = "sns.amazonaws.com"
        },
        Action   = "lambda:InvokeFunction",
        Resource = aws_lambda_function.atlantis.arn
      }
    ]
  })
}

data "template_file" "atlantis_policy" {
  template = file("${path.module}/atlantis_policy.json")

  vars = {
    developers_approval = var.developers_approval
    testers_approval    = var.testers_approval
    leads_approval      = var.leads_approval
  }
}

resource "aws_s3_bucket_object" "atlantis_policy" {
  bucket  = aws_s3_bucket.atlantis.id
  key     = "atlantis_policy.json"
  content = data.template_file.atlantis_policy.rendered
}

resource "aws_s3_bucket_policy" "atlantis_bucket" {
  bucket = aws_s3_bucket.atlantis.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowGetAndPut",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject", "s3:PutObject"],
        Resource  = "${aws_s3_bucket.atlantis.arn}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "atlantis_s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda.name
}

resource "aws_s3_bucket_notification" "atlantis_policy_update" {
  bucket = aws_s3_bucket.atlantis.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.atlantis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "atlantis_policy"
  }
}

output "atlantis_endpoint" {
  value = aws_lambda_function.atlantis.invoke_arn
}
*/