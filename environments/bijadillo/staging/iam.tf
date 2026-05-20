# ─── Deploy role for GitHub Actions (OIDC) ───
# EC2 role removed — behemoth (trading) EC2 role now covers all bijadillo permissions.

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

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "EC2Deploy"
    actions = [
      "ec2:DescribeInstances",
      "ec2:StartInstances",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "bijadillo-${var.env}-deploy-policy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
