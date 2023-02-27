resource "aws_iam_role" "codepipeline" {
  name = "serverpod-codepipeline"

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

resource "aws_iam_policy" "codepipeline" {
  name = "serverpod-codepipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ]
        Effect   = "Allow"
        Resource = aws_codecommit_repository.code.arn
      },
      {
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:PutFile",
          "codecommit:CreateBranch",
          "codecommit:CreateCommit",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive",
          "codecommit:MergePullRequestByThreeWay"
        ]
        Effect   = "Allow"
        Resource = aws_codecommit_repository.infrastructure.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:GetBucketLocation",
          "s3:GetObjectAcl",
          "s3:GetObjectTagging",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = aws_iam_role.ecs_task_execution_role.arn
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = aws_iam_policy.codepipeline.arn
  role       = aws_iam_role.codepipeline.name
}
