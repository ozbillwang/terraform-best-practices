resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "test-d"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "AWS/ApiGateway",
            "4XXError",
            "name",
            "${var.example}"
          ],
          [
           "AWS/ApiGateway",
            "5XXError",
            "name",
            "${var.example}"
          ]
        ],
        "period": 60,
        "stat": "Sum",
        "region": "enter-region",
        "title": "dashboard for 4XXError and 5XXXError"
      }
    },
    {
      "type": "text",
      "x": 0,
      "y": 7,
      "width": 3,
      "height": 3,
      "properties": {
        "markdown": "Hello world"
      }
    }
  ]
}
EOF
}
