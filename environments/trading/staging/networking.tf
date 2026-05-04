# Use the default VPC — no custom VPC needed for a single-bot staging environment.
# Default VPC exists in every AWS account, already has subnets in each AZ.
# Avoids creating/managing a VPC, IGW, route tables, and subnet associations.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# RDS requires a subnet group spanning at least 2 AZs.
# Default VPC subnets cover all AZs in the region — this satisfies that.
resource "aws_db_subnet_group" "trading" {
  name       = "behemoth-staging-db"
  subnet_ids = data.aws_subnets.default.ids
}
