# --- Key Pair ---
resource "aws_key_pair" "this" {
  key_name   = "${var.env}-terra-automate-key"
  public_key = file(var.key_public_path)
}

# --- Default VPC ---
resource "aws_default_vpc" "default" {}

# --- Security Group ---
resource "aws_security_group" "this" {
  name        = "${var.env}-terra-security-group"
  vpc_id      = aws_default_vpc.default.id
  description = "Allow SSH and HTTP inbound, all outbound - ${var.env}"

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-security-group"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- EC2 Instances ---
resource "aws_instance" "this" {
  count = var.instance_count

  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.common_tags, {
    Name = "${var.env}-terra-server-${count.index + 1}"
  })
}
