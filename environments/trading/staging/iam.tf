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
  name               = "behemoth-staging-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "behemoth_ssm" {
  statement {
    sid     = "ReadStagingParams"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:us-east-1:670074751531:parameter/behemoth.staging.*",
    ]
  }
  statement {
    sid     = "DecryptSecureStrings"
    actions = ["kms:Decrypt"]
    # aws/ssm is the AWS-managed key alias — cannot be deleted, no access loss risk
    resources = ["arn:aws:kms:us-east-1:670074751531:key/alias/aws/ssm"]
  }
  statement {
    sid     = "CloudWatchLogs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [
      "arn:aws:logs:us-east-1:670074751531:log-group:/behemoth/*",
    ]
  }
}

resource "aws_iam_role_policy" "behemoth_ssm" {
  name   = "behemoth-staging-ssm-access"
  role   = aws_iam_role.behemoth.id
  policy = data.aws_iam_policy_document.behemoth_ssm.json
}

resource "aws_iam_instance_profile" "behemoth" {
  name = "behemoth-staging-ec2"
  role = aws_iam_role.behemoth.name
}
