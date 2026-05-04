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

resource "aws_cloudwatch_dashboard" "behemoth" {
  dashboard_name = "behemoth-${var.env}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          title  = "Bot Logs"
          region = "us-east-1"
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.bot.name}' | fields @timestamp, level, msg | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 4
        properties = {
          title  = "Errors"
          region = "us-east-1"
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.errors.name}' | fields @timestamp, msg | sort @timestamp desc | limit 20"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 10
        width  = 8
        height = 4
        properties = {
          title   = "Candles Fetched"
          region  = "us-east-1"
          period  = 300
          stat    = "Sum"
          metrics = [["Behemoth/${title(var.env)}", "CandlesFetched", "symbol", "BTC/USDT"]]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 10
        width  = 8
        height = 4
        properties = {
          title   = "API Errors"
          region  = "us-east-1"
          period  = 300
          stat    = "Sum"
          metrics = [["Behemoth/${title(var.env)}", "APIErrors", "symbol", "BTC/USDT"]]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 10
        width  = 8
        height = 4
        properties = {
          title   = "Fetch Latency (ms)"
          region  = "us-east-1"
          period  = 300
          stat    = "Average"
          metrics = [["Behemoth/${title(var.env)}", "FetchLatencyMs", "symbol", "BTC/USDT"]]
        }
      }
    ]
  })
}
