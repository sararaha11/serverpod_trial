locals {
  groups = {
    developers = [
      "user1",
      "user2",
    ],
    testers = [
      "user2",
      "user3",
    ],
    leads = [
      "user3",
    ],
  }

  users = {
    user1 = {
      name   = "User One"
      email  = "user1@example.com"
      groups = ["developers"]
    },
    user2 = {
      name   = "User Two"
      email  = "user2@example.com"
      groups = ["developers", "testers"]
    },
    user3 = {
      name   = "User Three"
      email  = "user3@example.com"
      groups = ["testers", "leads"]
    },
  }
}

resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group" "testers" {
  name = "testers"
}

resource "aws_iam_group" "leads" {
  name = "leads"
}

resource "aws_iam_user" "users" {
  for_each = local.users

  name = each.key

  tags = {
    Name = each.value.name
  }
}

resource "aws_iam_group_membership" "developers" {
  for_each = { for u in local.groups.developers : u => u }

  name = aws_iam_group.developers.name
  users = [
    aws_iam_user.users[each.value].name,
  ]
}

resource "aws_iam_group_membership" "testers" {
  for_each = { for u in local.groups.testers : u => u }

  name = aws_iam_group.testers.name
  users = [
    aws_iam_user.users[each.value].name,
  ]
}

resource "aws_iam_group_membership" "leads" {
  for_each = { for u in local.groups.leads : u => u }

  name = aws_iam_group.leads.name
  users = [
    aws_iam_user.users[each.value].name,
  ]
}

resource "aws_iam_access_key" "users" {
  for_each = aws_iam_user.users

  user = each.value.name
}

resource "aws_secretsmanager_secret" "user_access_keys" {
  for_each = aws_iam_user.users

  name = "user-${each.value.name}-access-keys"
}

resource "aws_secretsmanager_secret_version" "user_access_keys" {
  for_each = aws_secretsmanager_secret.user_access_keys

  secret_id = aws_secretsmanager_secret.user_access_keys[each.key].id
  secret_string = jsonencode({
    access_key = aws_iam_access_key.users[each.key].id,
    secret_key = aws_iam_access_key.users[each.key].secret
  })
}

output "user_access_keys_secret_arn" {
  value = [for k, v in aws_secretsmanager_secret.user_access_keys : v.arn]
}

output "user_access_keys_secret_version_arn" {
  value = [for k, v in aws_secretsmanager_secret_version.user_access_keys : v.arn]
}
