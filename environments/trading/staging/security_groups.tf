resource "aws_security_group" "ec2" {
  name        = "behemoth-${var.env}-ec2"
  description = "Behemoth ${var.env} EC2 - SSH from operator IP only"
  vpc_id      = data.aws_vpc.default.id

  tags = { Name = "behemoth-${var.env}-ec2-sg" }

  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
