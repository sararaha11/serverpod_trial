
//--------------------------------------------------------------------------------------------------------
variable "project_name" {
  type = string
}

variable "repo_name" {
  type = string
}

variable "environments" {
  type    = list(string)
  default = ["dev", "qa", "prod"]
}

resource "aws_codepipeline" "pipeline" {
  count = length(var.environments)

  name = "pipeline-${var.environments[count.index]}"

  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration {
        RepositoryName = var.repo_name
        BranchName     = var.environments[count.index]
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration {
        ProjectName = var.project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ManualApproval"
      input_artifacts = ["build_output"]
      configuration {
        NotificationArn = aws_sns_topic.pipeline.arn
        CustomData      = "Please review and approve this deployment."
      }
    }

    action {
      name            = "Atlantis"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "Lambda"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration {
        FunctionName = aws_lambda_function.atlantis.function_name
        UserParameters = jsonencode({
          PLANFILE_S3_BUCKET = aws_s3_bucket.atlantis_planfiles.bucket
          PLANFILE_S3_KEY    = "${var.environments[count.index]}-${var.project_name}-${var.repo_name}-${local.timestamp}-plan"
          APPROVAL_COUNT     = var.environments[count.index] == "dev" ? 1 : 2
        })
      }
    }
  }
}

output "pipeline_names" {
  value = aws_codepipeline.pipeline[*].name
}


//----------------------------------------------


variable "github_webhook_secret" {}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda" {
  name = "lambda-atlantis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lambda_function" "atlantis" {
  filename      = "atlantis.zip"
  function_name = "atlantis"
  role          = aws_iam_role.lambda.arn
  handler       = "main"
  runtime       = "go1.x"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      ATLANTIS_ALLOW_REPO_CONFIG = "true"
      ATLANTIS_REPO_ALLOWLIST     = "org/repo"
      GITHUB_WEBHOOK_SECRET       = var.github_webhook_secret
      ATLANTIS_WORKDIR            = "/tmp/workspace"
      ATLANTIS_SKIP_CLONE         = "false"
      ATLANTIS_AUTOMERGE          = "false"
      ATLANTIS_AUTOMERGE_SLACK_CHANNEL = "#atlantis-automerge"
      ATLANTIS_AUTOMERGE_SLACK_TEMPLATE = <<EOF
{
    "text": "Atlantis automerge summary",
    "attachments": [
        {
            "color": "{{if .Merged}}good{{else}}warning{{end}}",
            "fields": [
                {
                    "title": "Pull Request",
                    "value": "{{.RepoFullName}}#{{.Num}}",
                    "short": true
                },
                {
                    "title": "Author",
                    "value": "<{{.Author}}|{{.Author}}>",
                    "short": true
                },
                {
                    "title": "Merged",
                    "value": "{{if .Merged}}Yes{{else}}No{{end}}",
                    "short": true
                },
                {
                    "title": "Title",
                    "value": "{{.Title}}",
                    "short": false
                }
            ]
        }
    ]
}
EOF
    }
  }

  source_code_hash = filebase64sha256("atlantis.zip")
}



resource "aws_iam_policy_attachment" "lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_policy_attachment" "s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.lambda.name
}

resource "aws_apigatewayv2_api" "atlantis" {
  name          = "atlantis"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "atlantis" {
  api_id               = aws_apigatewayv2_api.atlantis.id
  integration_type     = "AWS_PROXY"
  integration_uri      = aws_lambda_function.atlantis.invoke_arn
  integration_method   = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "atlantis" {
  api_id    = aws_apigatewayv2_api.atlantis.id
  route_key = "POST /atl"

  target = "integrations/${aws_apigatewayv2_integration.atlantis.id}"

  authorization_type = "NONE"

  depends_on = [
    aws_apigatewayv2_integration.atlantis
  ]
}

resource "aws_apigatewayv2_deployment" "atlantis" {
  api_id      = aws_apigatewayv2_api.atlantis.id
  description = "Deployment for Atlantis API Gateway"

  depends_on = [
    aws_apigatewayv2_stage.atlantis
  ]
}

resource "aws_apigatewayv2_stage" "atlantis" {
  name               = "atlantis"
  api_id             = aws_apigatewayv2_api.atlantis.id
  auto_deploy        = true
  deployment_id      = aws_apigatewayv2_deployment.atlantis.id
  default_route_settings {
    data_trace_enabled = true
    detailed_metrics_enabled = true
  }
}
