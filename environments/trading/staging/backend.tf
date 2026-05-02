terraform {
  backend "s3" {
    bucket  = "eccensia-tfstate-trading-staging"
    key     = "trading/staging/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # No DynamoDB lock — solo dev, single pipeline, no concurrent applies
  }
}
