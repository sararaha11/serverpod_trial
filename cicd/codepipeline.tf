module "codepipeline_dev" {
  source            = "./modules/codepipeline"
  env               = "dev"
  codebuild_image   = var.codebuild_image
  codecommit_repo   = var.app_codecommit_repository_name
  codepipeline_name = "${var.codepipeline_name}-dev"
  subnet_ids        = ["subnet-12345678", "subnet-87654321"]
  ami               = "ami-0123456789abcdef0"
  vpc_id            = 


}

module "codepipeline_qa" {
  source            = "./modules/codepipeline"
  env               = "qa"
  codebuild_image   = var.codebuild_image
  codecommit_repo   = var.app_codecommit_repository_name
  codepipeline_name = "${var.codepipeline_name}-qa"
}

module "codepipeline_prod" {
  source            = "./modules/codepipeline"
  env               = "prod"
  codebuild_image   = var.codebuild_image
  codecommit_repo   = var.app_codecommit_repository_name
  codepipeline_name = "${var.codepipeline_name}-prod"
  ami               = "ami-0123456789abcdef0"

}


