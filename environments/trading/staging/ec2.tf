data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "alejocc" {
  key_name   = "alejocc-ed25519"
  public_key = var.ssh_public_key
}

resource "aws_instance" "behemoth" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.alejocc.key_name
  iam_instance_profile   = aws_iam_instance_profile.behemoth.name

  # IMDSv2 required (secure default).
  # hop_limit=2 so Docker containers on this host can reach instance metadata
  # and inherit the IAM instance profile (boto3 uses IMDS for credentials).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    # Encrypted with AWS-managed key (aws/ebs).
    # AWS-managed keys cannot be deleted or disabled by you — no access loss risk.
    encrypted = true
  }
}

resource "aws_eip" "behemoth" {
  instance = aws_instance.behemoth.id
  domain   = "vpc"
}
