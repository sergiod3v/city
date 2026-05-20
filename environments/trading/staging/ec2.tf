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

resource "aws_key_pair" "behemoth" {
  key_name   = "behemoth-${var.env}-key"
  public_key = var.ssh_public_key
  tags       = { Name = "behemoth-${var.env}-key" }
}

resource "aws_instance" "behemoth" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.behemoth.key_name
  iam_instance_profile   = aws_iam_instance_profile.behemoth.name

  tags = { Name = "behemoth-${var.env}-bot" }

  # IMDSv2 required. hop_limit=2 so Docker containers inherit the IAM instance profile.
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

    # SQLite data dir — persists bot DB across container restarts via volume mount
    mkdir -p /opt/behemoth/data
    chown ec2-user:ec2-user /opt/behemoth/data

    # Docker Compose v2
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Bijadillo dirs — nginx conf, certs, ACME webroot, secrets
    mkdir -p /opt/bijadillo/nginx/{conf.d,certs,webroot}
    mkdir -p /opt/bijadillo/secrets
    chown -R ec2-user:ec2-user /opt/bijadillo
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    # AWS-managed key (aws/ebs) — cannot be deleted or disabled by you.
    encrypted = true
    tags      = { Name = "behemoth-${var.env}-root-vol" }
  }
}

resource "aws_eip" "behemoth" {
  instance = aws_instance.behemoth.id
  domain   = "vpc"
  tags     = { Name = "behemoth-${var.env}-eip" }
}
