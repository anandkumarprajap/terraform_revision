resource "aws_dynamodb_table" "this" {
  count        = var.table_count
  name         = "${var.env}-terra-workspace-table-${count.index + 1}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-workspace-table-${count.index + 1}"
  })
}
