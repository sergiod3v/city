data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "behemoth" {
  name               = "behemoth-${var.env}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "behemoth-${var.env}-ec2-role" }
}

data "aws_iam_policy_document" "behemoth_ssm" {
  statement {
    sid     = "ReadEnvParams"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/behemoth.${var.env}.*",
    ]
  }
  statement {
    sid     = "DecryptSecureStrings"
    actions = ["kms:Decrypt"]
    # AWS-managed SSM key — cannot be deleted or disabled by you.
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"]
  }
  statement {
    sid     = "CloudWatchLogs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/behemoth/${var.env}/*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/behemoth/${var.env}/*:log-stream:*",
    ]
  }
}

resource "aws_iam_role_policy" "behemoth_ssm" {
  name   = "behemoth-${var.env}-ssm-access"
  role   = aws_iam_role.behemoth.id
  policy = data.aws_iam_policy_document.behemoth_ssm.json
}

resource "aws_iam_instance_profile" "behemoth" {
  name = "behemoth-${var.env}-ec2"
  role = aws_iam_role.behemoth.name
  tags = { Name = "behemoth-${var.env}-instance-profile" }
}
