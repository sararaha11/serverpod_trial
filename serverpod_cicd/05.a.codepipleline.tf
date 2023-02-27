# Define the S3 bucket that will be used to store the pipeline artifacts
resource "aws_s3_bucket" "pipeline_artifacts_bucket" {
  bucket = "serverpod-pipeline-artifacts-${var.environment}"
}

# Define the CodePipeline

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

# Create the CodePipeline webhook for GitHub
resource "aws_codepipeline_webhook" "app_github_webhook" {
  name            = "app-github-webhook"
  target_pipeline = aws_codepipeline.app_pipeline.name
  authentication {
    type = "GITHUB_HMAC"
  }
  authentication_configuration {
    secret_token = var.github_webhook_secret
  }
  target_action {
    category = "Source"
    owner    = "AWS"
    provider = "CodeCommit"
    version  = "1"
  }
}