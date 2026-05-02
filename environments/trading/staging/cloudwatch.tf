resource "aws_cloudwatch_log_group" "bot" {
  name              = "/behemoth/bot"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "errors" {
  name              = "/behemoth/errors"
  retention_in_days = 30
}
