resource "aws_vpc" "trading" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "trading" {
  vpc_id = aws_vpc.trading.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.trading.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.trading.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.trading.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.trading.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trading.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_db_subnet_group" "trading" {
  name       = "behemoth-staging-db"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
