variable "pgp_key" {
  default = "arn:aws:secretsmanager:us-east-1:970261989069:secret:common/pgp/iamusers-mhQSz7"
}

data "aws_iam_policy_document" "dev_branch_policy" {
  statement {
    sid    = "DevBranchAccess"
    effect = "Allow"
    actions = [
      "codecommit:GitPush",
    ]
    resources = [
      "${aws_codecommit_repository.infra_repo.arn}:refs/heads/featuredev",
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:group/developers", "arn:aws:iam::${var.account_id}:group/testers", "arn:aws:iam::${var.account_id}:group/leads"]
    }
  }
}

data "aws_iam_policy_document" "qa_branch_policy" {
  statement {
    sid    = "QaBranchAccess"
    effect = "Allow"
    actions = [
      "codecommit:GitPush",
    ]
    resources = [
      "${aws_codecommit_repository.infra_repo.arn}:refs/heads/featureqa",
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:group/testers", "arn:aws:iam::${var.account_id}:group/leads"]
    }
  }
}

data "aws_iam_policy_document" "prod_branch_policy" {
  statement {
    sid    = "ProdBranchAccess"
    effect = "Allow"
    actions = [
      "codecommit:GitPush",
    ]
    resources = [
      "${aws_codecommit_repository.infra_repo.arn}:refs/heads/featureprod",
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:group/leads"]
    }
  }
}


data "s3_bucket_object" "user_groups_file" {
  bucket = var.s3_bucket_name
  key    = var.s3_user_groups_file_key

  depends_on = [
    aws_s3_bucket_object.user_groups_file_upload
  ]
}

locals {
  user_groups = jsondecode(data.s3_bucket_object.user_groups_file.body)["users"]
}

resource "aws_iam_user" "iam_users" {
  for_each = { for user in local.user_groups : user.username => user }

  name = each.value.username
  path = "/"

  tags = {
    FullName = each.value.full_name
    Email    = each.value.email
  }
}

resource "aws_iam_group" "iam_groups" {
  for_each = { for user in local.user_groups : user.groups[*] => user.username }

  name = each.key
  path = "/"

  tags = {
    Environment = each.key
  }
}

resource "aws_iam_user_group_membership" "iam_user_group_membership" {
  for_each = { for user in local.user_groups : user.username => user }

  user   = aws_iam_user.iam_users[each.key].name
  groups = each.value.groups
}

resource "aws_access_key" "iam_user_access_keys" {
  for_each = { for user in local.user_groups : user.username => user }

  user    = aws_iam_user.iam_users[each.key].name
  pgp_key = var.pgp_key

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret" "iam_user_secrets" {
  for_each = { for user in local.user_groups : user.username => user }

  name = "${var.project_name}-iam-user-secret-${each.key}"

  tags = {
    FullName = each.value.fullname
    Email    = each.value.email
  }
}

resource "aws_secretsmanager_secret_version" "iam_user_secret_versions" {
  for_each = { for user in local.user_groups : user.username => user }

  secret_id = aws_secretsmanager_secret.iam_user_secrets[each.key].id
  secret_string = jsonencode({
    access_key = aws_access_key.iam_user_access_keys[each.key].id
    secret_key = aws_access_key.iam_user_access_keys[each.key].secret
  })
}

resource "aws_sns_topic" "serverpod-project-sns-topic" {
  name = "serverpod-project-sns-topic"
}

resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each = {for user_group in local.user_groups: user_group.email => user_group}

  topic_arn = aws_sns_topic.pipeline.arn
  protocol  = "email"
  endpoint  = each.key
}

/*resource "aws_sns_topic_subscription" "email" {
  count         = length(local.user_group)
  topic_arn     = aws_sns_topic.example.arn
  protocol      = "email"
  endpoint      = local.user_group[count.index]["email"]
}*/

data "aws_sns_topic" "serverpod-project-sns-topic" {
  name = "serverpod-project-sns-topic"
}

resource "aws_sns_topic_policy" "serverpod-project-sns-topic-policy" {
  arn = data.aws_sns_topic.serverpod-project-sns-topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = data.aws_sns_topic.serverpod-project-sns-topic.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:ses:${var.region}:${var.account_id}:identity/*"
          }
        }
      }
    ]
  })
}