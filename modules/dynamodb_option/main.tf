resource "aws_dynamodb_table" "aq_data_dynamodb_table" {
  name           = "aq_measurements"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "device_id"
  range_key      = "time"

  tags = {
    app = "aq_data",
    flow = "dynamodb"
  }

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "time"
    type = "S"
  }
}



resource "aws_iot_topic_rule" "aq_dynamodb_rule" {
  name        = "AQ_DynamoDB_Measurement_Rule"
  description = "IoT Topic DynamoDB Rule for AQ measurements"
  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"

  tags = {
    app = "aq_data",
    flow = "dynamodb"
  }

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

  tags = {
    app = "aq_data",
    flow = "dynamodb"
  }

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

  tags = {
    app = "aq_data",
    flow = "dynamodb"
  }

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