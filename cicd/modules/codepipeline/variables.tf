/*variable "env" {
  description = "The environment to deploy to"
  default     = "dev"
}

variable "codebuild_image" {
  description = "The name of the CodeBuild image to use"
}

variable "codepipeline_name" {
  description = "The name of the CodePipeline project"
}

variable "codecommit_repo" {
  description = "The name of the CodePipeline project"
}
*/

variable "env" {
  description = "The environment to deploy to"
  default     = "dev"
}

variable "region" {
  description = "The AWS region to deploy to"
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy to"
}

variable "subnet_ids" {
  description = "The IDs of the subnets to deploy to"
  type        = list(string)
}

variable "ami" {
  description = "The ID of the AMI to use"
}

variable "instance_type" {
  description = "The type of EC2 instance to use"
  default     = "t2.micro"
}

variable "key_name" {
  description = "The name of the EC2 key pair"
}

variable "codepipeline_name" {
  description = "The name of the CodePipeline project"
  default = "rollfi-serverpod-codepipeline"
}

variable "codebuild_image" {
  description = "The name of the CodeBuild image to use"
}

variable "codecommit_repository_name" {
  description = "The name of the CodeCommit repository"
}

variable "atlantis_region" {
  description = "The AWS region to deploy Atlantis to"
  default     = "us-west-2"
}

variable "atlantis_domain_name" {
  description = "The domain name to use for the Atlantis API Gateway"
}
