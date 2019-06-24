# codes for pip install and zip packaging
resource "null_resource" "pip" {
  triggers {
    main         = "${base64sha256(file("${path.module}/source/main.py"))}"
    requirements = "${base64sha256(file("${path.module}/source/requirements.txt"))}"
    execute      = "${base64sha256(file("${path.module}/pip.sh"))}"
  }

  provisioner "local-exec" {
    command = "${path.module}/pip.sh ${path.module}/source"
  }
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/source"
  output_path = "${path.module}/source.zip"

  depends_on = ["null_resource.pip"]
}

# codes for lambda functions
resource "aws_iam_role" "lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "source" {
  filename         = "${path.module}/source.zip"
  source_code_hash = "${data.archive_file.source.output_base64sha256}"
  function_name    = "lamda"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "main.handler"
  runtime          = "python2.7"
  timeout          = 120

  environment {
    variables = {
      HASH = "${base64sha256(file("source/main.py"))}-${base64sha256(file("source/requirements.txt"))}"
    }
  }

  lifecycle {
    ignore_changes = ["source_code_hash", "last_modified"]
  }
}
