#######################################################################################################################
# TODO: https://silvr.medium.com/aws-timestream-with-terraform-259eaa9960d1

#######################################################################################################################
resource "aws_kinesis_stream" "aq_data_stream" {
  #  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream
  #  Kinesis Data Stream for raw aq measurement data
  name             = "aq-data-stream"
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

resource "aws_timestreamwrite_database" "aq_time_stream" {
  database_name = "aq-time-stream"

  tags = {
    Flow = "timestream"
  }
}


resource "aws_timestreamwrite_table" "aq_time_stream_table" {
  #  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/timestreamwrite_table
  database_name = aws_timestreamwrite_database.aq_time_stream.database_name
  table_name    = "aq_data"

  schema {
    composite_partition_key {
      enforcement_in_record = "REQUIRED"
      name                  = "device"
      type                  = "DIMENSION"
    }
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  retention_properties {
#    TODO: adjust retention period values!!!
    magnetic_store_retention_period_in_days = 1
    memory_store_retention_period_in_hours  = 1
  }

#  TODO: partition key
}

resource "aws_iot_topic_rule" "rule" {
  #  IoT topic rule to direct data published in MQTT topic to the Kinesis Data Stream
  name        = "AQ_MeasurementRule"
  description = "IoT Topic Rule for AQ measurements"
  enabled     = true
  sql         = "SELECT temperature, humidity, time FROM 'aq/measurement'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn    = aws_iam_role.iot_role.arn
    stream_name = aws_kinesis_stream.aq_data_stream.name
    partition_key = "$${device}"
  }

  timestream {
    database_name = aws_timestreamwrite_database.aq_time_stream.database_name
    table_name = aws_timestreamwrite_table.aq_time_stream_table.table_name
    role_arn = aws_iam_role.iot_role.arn
    dimension {
      name  = "device"
      value = "$${device}"
    }
    timestamp {
      unit  = "MILLISECONDS"
      value = "$${time_to_epoch(time, 'yyyy-MM-dd HH:mm:ss')}"
    }
  }
}


# IAM
resource "aws_iam_role" "iot_role" {
  name = "iot_role"

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

resource "aws_iam_policy" "kinesis_publish_policy" {
  name        = "kinesis_publish_policy"
  description = "Policy to allow publishing to Kinesis Data Stream"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"],
        Effect   = "Allow",
        Resource = aws_kinesis_stream.aq_data_stream.arn
      }
      # Add more statements as needed for other permissions
    ]
  })
}

resource "aws_iam_policy" "timestream_publish_policy" {
  name = "timestream_publish_policy"
  description = "Policy to allow publishing to Timestream"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "timestream:WriteRecords",
          "timestream:WriteRecords",
        ],
        Effect   = "Allow",
        Resource = aws_timestreamwrite_table.aq_time_stream_table.arn
      },
      {
        Action = [
          "timestream:DescribeEndpoints",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
      # Add more statements as needed for other permissions
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kinesis_publish_attachment" {
  policy_arn = aws_iam_policy.kinesis_publish_policy.arn
  role       = aws_iam_role.iot_role.name
}

resource "aws_iam_role_policy_attachment" "timestream_publish_attachment" {
  policy_arn = aws_iam_policy.timestream_publish_policy.arn
  role       = aws_iam_role.iot_role.name
}

## Optionally, you might want to output the IAM role ARN for reference
output "iot_kinesis_role_arn" {
  value = aws_iam_role.iot_role.arn
}

output "kinesis_stream_arn" {
  value = aws_kinesis_stream.aq_data_stream.arn
}

resource "aws_s3_bucket" "measurements_bucket" {
  bucket = "idealaq-aq-measurements-bucket"

  tags = {
    Name        = "AQ measurements bucket"
    Environment = "Dev"
  }
}