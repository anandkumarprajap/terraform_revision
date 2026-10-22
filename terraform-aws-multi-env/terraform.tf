terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # --- Remote Backend with S3 State Storage & DynamoDB State Locking ---
  # To enable remote state and team collaboration:
  # 1. Create S3 bucket (e.g., terraform-state-bab-bucket-demo)
  # 2. Create DynamoDB table (e.g., terraform-state-locks) with Partition Key: LockID (String)
  # 3. Uncomment this block and run: terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket         = "terraform-state-bab-bucket-demo"
  #   key            = "workspace-practice/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "terraform-state-locks"
  #   encrypt        = true
  # }
}
