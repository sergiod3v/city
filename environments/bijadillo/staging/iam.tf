data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bijadillo" {
  name               = "bijadillo-${var.env}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "bijadillo-${var.env}-ec2-role" }
}

data "aws_iam_policy_document" "bijadillo_ec2" {
  # SSM read for mercadillo secrets
  statement {
    sid     = "ReadMercadilloParams"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/mercadillo.${var.env}.*",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/mercadillo/${var.env}/*",
    ]
  }

  statement {
    sid     = "DecryptSecureStrings"
    actions = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"]
  }

  # CloudWatch logs for all bijadillo products
  statement {
    sid     = "CloudWatchLogs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/bijadillo/${var.env}/*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/bijadillo/${var.env}/*:log-stream:*",
    ]
  }

  # S3 assets bucket access
  statement {
    sid     = "S3AssetsAccess"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.mercadillo_assets.arn,
      "${aws_s3_bucket.mercadillo_assets.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "bijadillo_ec2" {
  name   = "bijadillo-${var.env}-ec2-policy"
  role   = aws_iam_role.bijadillo.id
  policy = data.aws_iam_policy_document.bijadillo_ec2.json
}

resource "aws_iam_instance_profile" "bijadillo" {
  name = "bijadillo-${var.env}-ec2"
  role = aws_iam_role.bijadillo.name
  tags = { Name = "bijadillo-${var.env}-instance-profile" }
}

# ─── Deploy role for GitHub Actions (OIDC) ───

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
  # EC2 lifecycle — start instance, manage SG for SSH
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
