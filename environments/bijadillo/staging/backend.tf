terraform {
  backend "s3" {
    bucket  = "bijadillo-tfstate-mercadillo-staging"
    key     = "bijadillo/staging/terraform.tfstate"
    region  = "us-east-1" # state bucket — intentionally us-east-1, not changed with infra region
    encrypt = true
    # No DynamoDB lock — solo dev, single pipeline, no concurrent applies
  }
}
