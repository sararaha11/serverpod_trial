resource "aws_codecommit_repository" "appcode_repository" {
  repository_name = "rollfi-app-repo"
  description     = "Code repository for serverpod application"
  default_branch  = "main"
  tags = {
    Project = "serverpod"
    Type    = "code"
  }
}

resource "aws_codecommit_repository" "infracode_repository" {
  repository_name = "rollfi-serverpod-infra-repo"
  description     = "Infrastructure repository for serverpod application"
  default_branch  = "main"
  tags = {
    Project = "serverpod"
    Type    = "infrastructure"
  }
}

resource "aws_codecommit_trigger" "atlantis" {
  repository_name = aws_codecommit_repository.appcode_repository.name
  trigger_name    = "Atlantis"
  events          = ["pull_request_created", "pull_request_updated"]
  destination_arn = aws_lambda_function.atlantis.arn
  branches        = ["main"]
}

resource "aws_codecommit_repository_webhook" "atlantis" {
  repository_name = aws_codecommit_repository.appcode_repository.name
  name            = "Atlantis"
  target_arn      = aws_lambda_function.atlantis.arn
  events          = ["pull_request_created", "pull_request_updated"]
  authentication = [{
    secret_token = random_password.webhook_secret.result
  }]
}
