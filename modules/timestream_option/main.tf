resource "aws_timestreamwrite_database" "aq_time_stream" {
  database_name = "aq-time-stream"

  tags = var.tags
}

resource "aws_timestreamwrite_table" "aq_time_stream_table" {
  #  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/timestreamwrite_table
  database_name = aws_timestreamwrite_database.aq_time_stream.database_name
  table_name    = var.table_name

  tags = var.tags

  schema {
    composite_partition_key {
      enforcement_in_record = "REQUIRED"
      name                  = "device_id"
      type                  = "DIMENSION"
    }
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  retention_properties {
    magnetic_store_retention_period_in_days = 1
    memory_store_retention_period_in_hours  = 1
  }

}

resource "aws_iot_topic_rule" "aq_timestream_rule" {
  #  IoT topic rule to direct data published in MQTT topic to the Kinesis Data Stream
  name        = "AQ_Timestream_MeasurementRule"
  description = "IoT Topic Timestream Rule for AQ measurements"

  tags = var.tags

  enabled     = true
  sql         = "SELECT * FROM '${var.iot_topic}'"
  sql_version = "2016-03-23"

  timestream {
    database_name = aws_timestreamwrite_database.aq_time_stream.database_name
    table_name = aws_timestreamwrite_table.aq_time_stream_table.table_name
    role_arn = aws_iam_role.iot_role.arn
    dimension {
      name  = "device_id"
      value = "$${device_id}"
    }
    timestamp {
      unit  = "MILLISECONDS"
      value = "$${time_to_epoch(time, 'yyyy-MM-dd HH:mm:ss')}"
    }
  }
}

resource "aws_iam_policy" "timestream_publish_policy" {
  name = "timestream_publish_policy"
  description = "Policy to allow publishing to Timestream"

  tags = var.tags

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

resource "aws_iam_role_policy_attachment" "timestream_publish_attachment" {
  policy_arn = aws_iam_policy.timestream_publish_policy.arn
  role       = aws_iam_role.iot_role.name
}

resource "aws_iam_role" "iot_role" {
  name = "iot_role"

  tags = var.tags

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