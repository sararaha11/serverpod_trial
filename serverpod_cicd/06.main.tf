module "infra" {
  source = "../infra"

  # Input variables for infrastructure module
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  key_name                   = var.key_name
}

resource "aws_s3_bucket_object" "app_archive" {
  depends_on = [module.infra]
  bucket     = module.infra.app_bucket_id
  key        = "${var.app_name}/${var.app_version}.zip"
  source     = "${path.cwd}/app/app.zip"
  etag       = filemd5("${path.cwd}/app/app.zip")
}

resource "aws_codedeploy_deployment_group" "app_deploy_group" {
  depends_on             = [aws_codedeploy_application.app_deploy_app]
  app_name               = aws_codedeploy_application.app_deploy_app.name
  deployment_group_name  = var.environment == "prod" ? "${var.app_name}-prod" : "${var.app_name}-${var.environment}"
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  service_role_arn       = aws_iam_role.codepipeline.arn
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  app_specification {
    content {
      content_type = aws_codedeploy_app_spec.app_spec.content_type
      data         = aws_codedeploy_app_spec.app_spec.content
    }
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    green_fleet_provisioning_option {
      action = "DISCOVER_EXISTING"
    }
  }

  load_balancer_info {
    target_group_info {
      name = module.infra.app_target_group_name
    }
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  ec2_tag_set {
    ec2_tag_set_list {
      ec2_tag_group {
        key   = "Name"
        value = var.environment == "prod" ? "${var.app_name}-prod" : "${var.app_name}-${var.environment}"
      }
      ec2_tag_group {
        key   = "Environment"
        value = var.environment
      }
    }
  }
}

resource "aws_codedeploy_deployment_config" "app_deployment_config" {
  deployment_config_name = "CodeDeployDefault.OneAtATime"
}

resource "aws_codedeploy_app_spec" "app_spec" {
  content_type = "application/json"
  content = templatefile("${path.module}/appspec.json.tpl",
    {
      app_name     = var.app_name
      app_version  = var.app_version
      environment  = var.environment
      infra_bucket = module.infra.infra_bucket_id
  })
}

resource "aws_s3_bucket_object" "app_spec" {
  depends_on = [module.infra]
  bucket     = module.infra.infra_bucket_id
  key        = "appspec/${var.app_name}_${var.app_version}.json"
  source     = "${path.module}/appspec.json.tpl"
}
