resource "aws_sns_topic" "sns" {
  name = "user-updates-topic"
}

locals {
  rest_api_id = aws_api_gateway_rest_api.panda.id
}

output "rest_api_id" {
    value = local.rest_api_id
}

resource "aws_route53_health_check" "http" {
  fqdn              =     format("%s.%s",aws_api_gateway_rest_api.panda.id,"execute-api.enter_region.amazonaws.com")
  insufficient_data_health_status = "Healthy"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "api-health-check"
  }
}
resource "aws_cloudwatch_metric_alarm" "http1" {
  depends_on          = [aws_route53_health_check.http]
  alarm_name          = "foobar"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.sns.arn]
  ok_actions          = [aws_sns_topic.sns.arn]

  dimensions = {
    HealthCheckName = "api-health-check"
  }
}
