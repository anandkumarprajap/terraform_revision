# ==============================================================================
# Terraform Import Configuration (Terraform 1.5+)
# ==============================================================================
# Use this configuration when you have an existing AWS resource (like an EC2 
# instance created manually in the AWS Console or via AWS CLI) that you want 
# to bring under Terraform management without destroying or recreating it.
#
# STEP 1: Uncomment the import block below and replace the id with your instance ID
# STEP 2: Uncomment the corresponding resource block below
# STEP 3: Run: terraform plan (Terraform will plan to IMPORT instead of create)
# STEP 4: Run: terraform apply (The instance is now tracked in your state file!)
# ==============================================================================

# --- Declarative Import Block (Modern Terraform 1.5+) ---
# import {
#   to = aws_instance.imported_ec2
#   id = "i-0123456789abcdef0" # <-- Replace with your existing EC2 Instance ID
# }

# --- Matching Resource Block ---
# resource "aws_instance" "imported_ec2" {
#   ami           = var.ami
#   instance_type = var.instance_type
#
#   tags = merge(local.common_tags, {
#     Name     = "${terraform.workspace}-imported-server"
#     Imported = "true"
#   })
# }

# ==============================================================================
# Alternative: CLI Import Command (All Terraform versions)
# ==============================================================================
# If using the CLI command approach instead of the import block:
#
# 1. Add the empty resource block above in your code (uncommented).
# 2. Run the command:
#      terraform import aws_instance.imported_ec2 i-0123456789abcdef0
# 3. Verify in state:
#      terraform state show aws_instance.imported_ec2
# ==============================================================================
