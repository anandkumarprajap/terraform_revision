resource "aws_s3_bucket" "this" {
  count  = var.bucket_count
  bucket = "${var.env}-terra-workspace-bucket-${count.index + 1}"

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-workspace-bucket-${count.index + 1}"
  })
}

resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.bucket_count
  bucket = aws_s3_bucket.this[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
