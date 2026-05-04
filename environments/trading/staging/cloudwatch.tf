resource "aws_cloudwatch_log_group" "bot" {
  name              = "/behemoth/${var.env}/bot"
  retention_in_days = 30
  tags              = { Name = "behemoth-${var.env}-bot-logs" }
}

resource "aws_cloudwatch_log_group" "errors" {
  name              = "/behemoth/${var.env}/errors"
  retention_in_days = 30
  tags              = { Name = "behemoth-${var.env}-error-logs" }
}
