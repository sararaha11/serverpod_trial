resource "aws_codecommit_repository" "code_repository" {
  repository_name = "rollfi-app-repo"
  description     = "Code repository for serverpod application"
  default_branch  = "main"
  tags = {
    Project = "serverpod"
    Type    = "code"
  }
}

resource "aws_codecommit_repository" "infra_repository" {
  repository_name = "rollfi-serverpod-infra-repo"
  description     = "Infrastructure repository for serverpod application"
  default_branch  = "main"
  tags = {
    Project = "serverpod"
    Type    = "infrastructure"
  }
}
