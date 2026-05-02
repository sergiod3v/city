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
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "behemoth" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.alejocc.key_name
  iam_instance_profile   = aws_iam_instance_profile.behemoth.name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y python3.11 python3.11-pip git postgresql15
    pip3.11 install --upgrade pip

    # Node + PM2
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
    npm install -g pm2

    # CloudWatch agent
    dnf install -y amazon-cloudwatch-agent

    # App directory
    mkdir -p /opt/behemoth
    chown ec2-user:ec2-user /opt/behemoth

    # Log dir for PM2
    mkdir -p /var/log/behemoth
    chown ec2-user:ec2-user /var/log/behemoth
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
}

resource "aws_eip" "behemoth" {
  instance = aws_instance.behemoth.id
  domain   = "vpc"
}
