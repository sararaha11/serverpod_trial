resource "aws_codepipeline" "example" {
  name     = var.codepipeline_name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name            = "SourceAction"
      category        = "Source"
      owner           = "AWS"
      provider        = "CodeCommit"
      version         = "1"
      output_artifacts = ["source_artifact"]

      configuration {
        RepositoryName = var.codecommit_repo
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "BuildAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts  = ["source_artifact"]
      output_artifacts = ["build_artifact"]

      configuration {
        ProjectName = aws_codebuild_project.example.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts  = ["build_artifact"]
      output_artifacts = []

      configuration {
        ClusterName = aws_ecs_cluster.example.name
        ServiceName = aws_ecs_service.example.name
      }
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.codepipeline_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "codepipeline" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
  roles      = [aws_iam_role.codepipeline.name]
}

resource "aws_codebuild_project" "example" {
  name = "${var.codepipeline_name}-build"
  description = "CodeBuild project for ${var.codepipeline_name}"
  service_role = aws_iam_role.codebuild.arn
  source {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = var.codebuild_image
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.codepipeline_name}-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "codebuild" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
  roles      = [aws_iam_role.codebuild.name]
}

resource "aws_iam_policy_attachment" "secrets_manager" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  roles      = [aws_iam_role.codebuild.name]
}

resource "aws_iam_policy" "codebuild" {
  name        = "${var.codepipeline_name}-build-policy"
  description = "Policy for ${var.codepipeline_name}-build role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
      {
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret.codebuild_access_keys.arn,
          "${aws_secretsmanager_secret.codebuild_access_keys.arn}*",
        ]
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "codebuild_access_keys" {
  name = "${var.codepipeline_name}-codebuild-access-keys"

  tags = {
    Environment = var.env
  }
}

resource "aws_secretsmanager_secret_version" "codebuild_access_keys" {
  secret_id     = aws_secretsmanager_secret.codebuild_access_keys.id
  secret_string = jsonencode(var.access_keys)
}

output "codebuild_access_keys_secret_arn" {
  value = aws_secretsmanager_secret.codebuild_access_keys.arn
}

output "codebuild_access_keys_secret_version_arn" {
  value = aws_secretsmanager_secret_version.codebuild_access_keys.arn
}
