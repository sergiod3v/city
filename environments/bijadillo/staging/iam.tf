# ─── Deploy role for GitHub Actions (OIDC) ───
# Inline policy removed — EC2 no longer exists (migrated to VPS).
# Re-attach a policy here when CI needs S3 or other AWS access.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:sergiod3v/mercadillo:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "bijadillo-${var.env}-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume.json
  tags               = { Name = "bijadillo-${var.env}-deploy-role" }
}
