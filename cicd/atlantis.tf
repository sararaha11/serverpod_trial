/*resource "aws_lambda_function" "atlantis" {
  filename      = "atlantis.zip"
  function_name = "atlantis"
  role          = aws_iam_role.lambda.arn
  handler       = "handler"
  runtime       = "go1.x"
  environment {
    variables = {
      ATLANTIS_REPO_ALLOWLIST = aws_codecommit_repository.example.name
    }
  }
}

resource "aws_lambda_permission" "atlantis" {
  statement_id  = "AllowExecutionFromCodeCommit"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atlantis.arn
  principal     = "codecommit.amazonaws.com"
  source_arn    = aws_codecommit_repository.example.arn
}

data "archive_file" "atlantis_zip" {
  type        = "zip"
  source_dir = "atlantis"
  output_path = "atlantis.zip"
}
*/

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "atlantis" {
  name = "atlantis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "atlantis" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      "${var.s3_bucket_name}/*",
      var.s3_bucket_name
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets"
    ]
    resources = [
      "arn:aws:s3:::*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sns:Publish",
      "sns:Subscribe",
      "sns:Unsubscribe"
    ]
    resources = [
      aws_sns_topic.atlantis_approval_dev.arn,
      aws_sns_topic.atlantis_approval_qa.arn,
      aws_sns_topic.atlantis_approval_prod.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.atlantis.arn
    ]
  }
}

resource "aws_iam_policy" "atlantis" {
  name   = "atlantis-policy"
  policy = data.aws_iam_policy_document.atlantis.json
}

resource "aws_iam_role_policy_attachment" "atlantis" {
  policy_arn = aws_iam_policy.atlantis.arn
  role       = aws_iam_role.atlantis.name
}

resource "aws_lambda_function" "atlantis" {
  filename      = "atlantis.zip"
  function_name = "atlantis"
  role          = aws_iam_role.atlantis.arn
  handler       = "main"
  runtime       = "go1.x"
  timeout       = 300

  environment {
    variables = {
      AWS_DEFAULT_REGION   = var.region
      ATLANTIS_S3_BUCKET   = var.s3_bucket_name
      ATLANTIS_ENVIRONMENT = var.environment
    }
  }

  source_code_hash = filebase64sha256("atlantis.zip")
}

resource "aws_lambda_permission" "atlantis" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atlantis.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_api_gateway_deployment.atlantis.execution_arn
}

resource "aws_api_gateway_rest_api" "atlantis" {
  name        = "atlantis"
  description = "API Gateway for Atlantis"
}

resource "aws_api_gateway_resource" "atlantis" {
  rest_api_id = aws_api_gateway_rest_api.atlantis.id
  parent_id   = aws_api_gateway_rest_api.atlantis.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "atlantis" {
  rest_api_id   = aws_api_gateway_rest_api.atlantis.id
  resource_id   = aws_api_gateway_resource.atlantis.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "atlantis" {
  rest_api_id             = aws_api_gateway_rest_api.atlantis.id
  resource_id             = aws_api_gateway_resource.atlantis.id
  http_method             = aws_api_gateway_method.atlantis.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.atlantis.invoke_arn
}

resource "aws_api_gateway_deployment" "atlantis" {
  rest_api_id = aws_api_gateway_rest_api.atlantis.id
  stage_name  = "dev"
  depends_on  = [aws_api_gateway_integration.atlantis]
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

resource "aws_sns_topic_policy" "atlantis_approval_dev" {
  arn = aws_sns_topic.atlantis_approval_dev.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublishFromLambda"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.atlantis_approval_dev.arn
      },
      {
        Sid    = "AllowSNSSubscription"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe"
        ]
        Resource = aws_sns_topic.atlantis_approval_dev.arn
        Condition = {
          StringEquals = {
            "aws:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "atlantis_approval_qa" {
  arn = aws_sns_topic.atlantis_approval_qa.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublishFromLambda"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.atlantis_approval_qa.arn
      },
      {
        Sid    = "AllowSNSSubscription"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe"
        ]
        Resource = aws_sns_topic.atlantis_approval_qa.arn
        Condition = {
          StringEquals = {
            "aws:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "atlantis_approval_prod" {
  arn = aws_sns_topic.atlantis_approval_prod.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublishFromLambda"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.atlantis_approval_prod.arn
      },
      {
        Sid    = "AllowSNSSubscription"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe"
        ]
        Resource = aws_sns_topic.atlantis_approval_prod.arn
        Condition = {
          StringEquals = {
            "aws:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowSNSTriggerLambdaFunction"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.atlantis.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_sns_topic.atlantis_approval_prod.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_object" "atlantis_policy" {
  bucket = var.s3_bucket_name
  key    = "atlantis_policy.json"
  source = "atlantis_policy.json"
  etag   = filemd5("atlantis_policy.json")
}

resource "aws_s3_bucket_policy" "atlantis" {
  bucket = var.s3_bucket_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3GetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${var.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_sns_topic.atlantis_approval_dev.arn
          }
        }
      },
      {
        Sid       = "AllowS3PutObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${var.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_sns_topic.atlantis_approval_dev.arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "codepipeline" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
  roles      = [aws_iam_role.codepipeline.name]
}

resource "aws_iam_user" "atlantis" {
  name = "atlantis"
}

resource "aws_iam_user_policy_attachment" "atlantis" {
  user       = aws_iam_user.atlantis.name
  policy_arn = aws_iam_policy.atlantis.arn
}

/*resource "aws_iam_policy" "atlantis" {
  name = "atlantis"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAssumeRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.atlantis.arn
      }
    ]
  })
}
*/

resource "aws_iam_access_key" "atlantis" {
  user = aws_iam_user.atlantis.name
}

resource "aws_secretsmanager_secret" "atlantis_access_key" {
  name = "atlantis_access_key"
}

resource "aws_secretsmanager_secret_version" "atlantis_access_key" {
  secret_id = aws_secretsmanager_secret.atlantis_access_key.id
  secret_string = jsonencode({
    access_key = aws_iam_access_key.atlantis.id
    secret_key = aws_iam_access_key.atlantis.secret
  })
}

resource "aws_s3_bucket_notification" "atlantis_policy" {
  bucket = var.s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.atlantis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "atlantis_policy.json"
  }
}


resource "random_password" "webhook_secret" {
  length  = 32
  special = true
}
