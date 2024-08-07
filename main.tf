#######################################################################################################################
# TODO: https://silvr.medium.com/aws-timestream-with-terraform-259eaa9960d1

#######################################################################################################################
variable "region" {
  description = "The AWS region to deploy the resources"
  default     = "eu-central-1"
}

variable "iot_topic" {
  description = "The MQTT topic for IoT Core"
  default     = "aq/measurement"
}

provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "aq_data_dynamodb_table" {
  name           = "aq_measurements"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "device_id"
  range_key      = "time"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "time"
    type = "S"
  }

  #  attribute {
  #    name = "sample_data"
  #    type = "S"
  #  }

  #  tags = {
  #
  #  }
  #  TODO: tags - everywhere!!! tag everything possible!!!
}



resource "aws_iot_topic_rule" "aq_dynamodb_rule" {
  name        = "AQ_DynamoDB_Measurement_Rule"
  description = "IoT Topic DynamoDB Rule for AQ measurements"
  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"

  dynamodb {
    role_arn        = aws_iam_role.aq_data_dynamodb_role.arn
    table_name      = aws_dynamodb_table.aq_data_dynamodb_table.name
    hash_key_field  = "device_id"
    hash_key_type   = "STRING"
    hash_key_value  = "$${device_id}"
    range_key_field = "time"
    range_key_type  = "STRING"
    range_key_value = "$${time}"
    payload_field   = "sample_data"
  }
}

resource "aws_iam_role" "aq_data_dynamodb_role" {
  name = "aq_data_dynamodb_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "iot.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aq_data_dynamodb_policy" {
  name        = "iot-dynamodb-policy"
  description = "Policy to allow IoT Core to write data to DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.aq_data_dynamodb_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iot_dynamodb_role_policy_attachment" {
  role       = aws_iam_role.aq_data_dynamodb_role.name
  policy_arn = aws_iam_policy.aq_data_dynamodb_policy.arn
}

# IoT Policy ====>
resource "aws_iot_policy" "aq_data_iot_core_policy" {
  name = "aq_data_iot_core_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "iot:Publish",
          "iot:Receive"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topic/${var.iot_topic}"
        ]
      },
      {
        Action = [
          "iot:Connect"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:client/aq*Client",
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:client/basicPubSub",
        ]
      },
      {
        Action = [
          "iot:Subscribe"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topicfilter/${var.iot_topic}"
        ]
      }
      # Add more statements as needed for other permissions
    ]
  })
}

data "aws_caller_identity" "current" {}

# ### certificates

resource "aws_iot_thing" "iot_thing" {
  name = "MyIotThing"
}

resource "aws_iot_certificate" "iot_cert" {
  active = true
}

resource "aws_iot_policy_attachment" "iot_policy_attachment" {
  policy = aws_iot_policy.aq_data_iot_core_policy.name
  target = aws_iot_certificate.iot_cert.arn
}

resource "aws_iot_thing_principal_attachment" "iot_thing_attachment" {
  thing     = aws_iot_thing.iot_thing.name
  principal = aws_iot_certificate.iot_cert.arn
}

output "certificate_arn" {
  value = aws_iot_certificate.iot_cert.arn
}

output "certificate_pem" {
  value = aws_iot_certificate.iot_cert.certificate_pem
  sensitive = true
}

output "private_key" {
  value = aws_iot_certificate.iot_cert.private_key
  sensitive = true
}

output "public_key" {
  value = aws_iot_certificate.iot_cert.public_key
  sensitive = true
}