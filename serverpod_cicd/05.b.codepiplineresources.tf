# Create the CodePipeline resources for the app module
module "app_pipeline" {
  source               = "./modules/codepipeline"
  name                 = "serverpod-app-pipeline"
  codecommit_repo_name = aws_codecommit_repository.app.name
  artifacts_bucket     = aws_s3_bucket.app_bucket.bucket
  source_branch        = "main"
  deploy_dev           = true
  deploy_qa            = true
  deploy_prod          = true
  dev_account_id       = var.dev_account_id
  qa_account_id        = var.qa_account_id
  prod_account_id      = var.prod_account_id
}
