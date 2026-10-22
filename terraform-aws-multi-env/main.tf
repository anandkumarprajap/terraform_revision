# ============================================================
# Workspace-Driven Infrastructure
# ============================================================
# Usage:
#   terraform workspace new dev   && terraform apply
#   terraform workspace new prod  && terraform apply
# ============================================================

locals {
  # Central config map — all per-environment differences in one place
  env_config = {
    dev = {
      instance_count = 2
      bucket_count   = 1
      table_count    = 1
    }
    prod = {
      instance_count = 3
      bucket_count   = 2
      table_count    = 2
    }
  }

  # Select config for current workspace, fallback to dev
  current = lookup(local.env_config, terraform.workspace, local.env_config["dev"])

  common_tags = {
    Environment = terraform.workspace
    ManagedBy   = "terraform"
    Project     = "workspace-practice"
  }
}

# --- EC2 Module ---
module "ec2" {
  source = "./modules/ec2"

  env             = terraform.workspace
  instance_count  = local.current.instance_count
  ami             = var.ami
  instance_type   = var.instance_type
  key_public_path = var.key_public_path
  common_tags     = local.common_tags
}

# --- S3 Module ---
module "s3" {
  source = "./modules/s3"

  env          = terraform.workspace
  bucket_count = local.current.bucket_count
  common_tags  = local.common_tags
}

# --- DynamoDB Module ---
module "dynamodb" {
  source = "./modules/dynamodb"

  env         = terraform.workspace
  table_count = local.current.table_count
  common_tags = local.common_tags
}
