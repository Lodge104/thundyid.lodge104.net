# Backend configuration for S3
# This file will be created by `terraform init` when you run it
# with the backend config options. You do not need to edit it.

terraform {
  backend "s3" {
    bucket         = "thundyid-terraform-state-423971488961"
    dynamodb_table = "thundyid-terraform-locks"
    encrypt        = true
    key            = "terraform.tfstate"
    region         = "us-east-1"
  }
}
