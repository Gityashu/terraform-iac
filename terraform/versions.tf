terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-state-bucket-2f"                  # <= EXACTLY MATCH YOUR S3 BUCKET NAME
    key            = "ec2-deployment/terraform.tfstate"          # <= Path within the bucket
    region         = "ap-south-1"                                # <= EXACTLY MATCH YOUR AWS_REGION SECRET
    #dynamodb_table = "terraform-lock-table"                      # <= EXACTLY MATCH YOUR DYNAMODB TABLE NAME
    encrypt        = true
  }
}