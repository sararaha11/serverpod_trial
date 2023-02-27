# Create IAM roles and policies for Atlantis
resource "aws_iam_role" "atlantis_role" {
  name = "serverpod-atlantis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "atlantis_policy" {
  name   = "serverpod-atlantis-policy"
  policy = data.aws_iam_policy_document.atlantis_policy.json
}

resource "aws_iam_role_policy_attachment" "atlantis_role_policy_attachment" {
  policy_arn = aws_iam_policy.atlantis_policy.arn
  role       = aws_iam_role.atlantis_role.name
}

data "aws_iam_policy_document" "atlantis_policy" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:CreateTags",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]

    resources = [
      "*"
    ]

    effect = "Allow"
  }
}
