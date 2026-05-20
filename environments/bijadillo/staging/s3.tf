# Product images, order exports, weekly price lists
resource "aws_s3_bucket" "mercadillo_assets" {
  bucket = "bijadillo-mercadillo-${var.env}-assets"
  tags   = { Name = "mercadillo-${var.env}-assets" }
}

resource "aws_s3_bucket_versioning" "mercadillo_assets" {
  bucket = aws_s3_bucket.mercadillo_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mercadillo_assets" {
  bucket = aws_s3_bucket.mercadillo_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mercadillo_assets" {
  bucket                  = aws_s3_bucket.mercadillo_assets.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
