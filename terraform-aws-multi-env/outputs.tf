output "current_workspace" {
  description = "The active Terraform workspace"
  value       = terraform.workspace
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2.instance_ids
}

output "ec2_public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = module.ec2.public_ips
}

output "s3_bucket_names" {
  description = "Names of the S3 buckets"
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = module.s3.bucket_arns
}

output "dynamodb_table_names" {
  description = "Names of the DynamoDB tables"
  value       = module.dynamodb.table_names
}

output "dynamodb_table_arns" {
  description = "ARNs of the DynamoDB tables"
  value       = module.dynamodb.table_arns
}

# --- Imported Resource Outputs (Uncomment if using import.tf) ---
# output "imported_ec2_id" {
#   description = "ID of the imported EC2 instance"
#   value       = try(aws_instance.imported_ec2.id, "Not imported")
# }
#
# output "imported_ec2_public_ip" {
#   description = "Public IP of the imported EC2 instance"
#   value       = try(aws_instance.imported_ec2.public_ip, "Not imported")
# }

