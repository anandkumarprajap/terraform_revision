output "bucket_names" {
  description = "Names of the S3 buckets"
  value       = aws_s3_bucket.this[*].bucket
}

output "bucket_arns" {
  description = "ARNs of the S3 buckets"
  value       = aws_s3_bucket.this[*].arn
}
