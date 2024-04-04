#######################################################################################################################
# TODO: https://silvr.medium.com/aws-timestream-with-terraform-259eaa9960d1

#######################################################################################################################

#TODO: uncomment to enable timestream
#resource "aws_timestreamwrite_database" "aq_time_stream" {
#  database_name = "aq-time-stream"
#
#  tags = {
#    Flow = "timestream"
#  }
#}

#TODO: uncomment to enable timestream
#resource "aws_timestreamwrite_table" "aq_time_stream_table" {
#  #  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/timestreamwrite_table
#  database_name = aws_timestreamwrite_database.aq_time_stream.database_name
#  table_name    = "aq_data"
#
#  schema {
#    composite_partition_key {
#      enforcement_in_record = "REQUIRED"
#      name                  = "device"
#      type                  = "DIMENSION"
#    }
#  }
#
#  magnetic_store_write_properties {
#    enable_magnetic_store_writes = true
#  }
#
#  retention_properties {
##    TODO: adjust retention period values!!!
#    magnetic_store_retention_period_in_days = 1
#    memory_store_retention_period_in_hours  = 1
#  }
#
#}

#  TODO: uncomment to enable timestream
#resource "aws_iot_topic_rule" "aq_timestream_rule" {
#  #  IoT topic rule to direct data published in MQTT topic to the Kinesis Data Stream
#  name        = "AQ_Timestream_MeasurementRule"
#  description = "IoT Topic Timestream Rule for AQ measurements"
#  enabled     = true
#  sql         = "SELECT temperature, humidity, time FROM 'aq/measurement'"
#  sql_version = "2016-03-23"

#  timestream {
#    database_name = aws_timestreamwrite_database.aq_time_stream.database_name
#    table_name = aws_timestreamwrite_table.aq_time_stream_table.table_name
#    role_arn = aws_iam_role.iot_role.arn
#    dimension {
#      name  = "device"
#      value = "$${device}"
#    }
#    timestamp {
#      unit  = "MILLISECONDS"
#      value = "$${time_to_epoch(time, 'yyyy-MM-dd HH:mm:ss')}"
#    }
#  }
#}

#TODO: uncomment to enable timestream
#resource "aws_iam_policy" "timestream_publish_policy" {
#  name = "timestream_publish_policy"
#  description = "Policy to allow publishing to Timestream"
#
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Action   = [
#          "timestream:WriteRecords",
#          "timestream:WriteRecords",
#        ],
#        Effect   = "Allow",
#        Resource = aws_timestreamwrite_table.aq_time_stream_table.arn
#      },
#      {
#        Action = [
#          "timestream:DescribeEndpoints",
#        ]
#        Effect   = "Allow"
#        Resource = "*"
#      }
#      # Add more statements as needed for other permissions
#    ]
#  })
#}

#TODO: uncomment to enable timestream
#resource "aws_iam_role_policy_attachment" "timestream_publish_attachment" {
#  policy_arn = aws_iam_policy.timestream_publish_policy.arn
#  role       = aws_iam_role.iot_role.name
#}

#TODO: uncomment to enable timestream
#resource "aws_iam_role" "iot_role" {
#  name = "iot_role"
#
#  assume_role_policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Action = "sts:AssumeRole",
#        Effect = "Allow",
#        Principal = {
#          Service = "iot.amazonaws.com"
#        }
#      }
#    ]
#  })
#}


resource "aws_iot_topic_rule" "aq_kinesis_rule" {
  name        = "AQ_Kinesis_Measurement_Rule"
  description = "IoT Topic Kinesis Rule for AQ measurements"
  enabled     = true
  sql         = "SELECT device, temperature, humidity, time FROM 'aq/measurement'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn      = aws_iam_role.iot_kinesis_s3_role.arn
    stream_name   = aws_kinesis_stream.aq_data_stream.name
    partition_key = "$${device}"
  }
}

resource "aws_kinesis_stream" "aq_data_stream" {
  #  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream
  #  Kinesis Data Stream for raw aq measurement data
  name             = "aq-data-stream"
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}



## Optionally, you might want to output the IAM role ARN for reference
#output "iot_kinesis_role_arn" {
#  value = aws_iam_role.iot_role.arn
#}

output "kinesis_stream_arn" {
  value = aws_kinesis_stream.aq_data_stream.arn
}


########################################################################################################################
########################################################################################################################
# Kinesis Firehouse -> S3
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-test-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.iot_kinesis_s3_role.arn
    bucket_arn = aws_s3_bucket.measurements_bucket.arn

    buffering_size     = 120
    buffering_interval = 60

    # https://docs.aws.amazon.com/firehose/latest/dev/dynamic-partitioning.html
    dynamic_partitioning_configuration {
      enabled = "true"
    }

    # Example prefix using partitionKeyFromQuery, applicable to JQ processor
    # For dynamic partitioning: https://analyticsweek.com/kinesis-data-firehose-now-supports-dynamic-partitioning-to-amazon-s3/
    prefix = "data/device=!{partitionKeyFromQuery:device}/year:!{partitionKeyFromQuery:year}/month:!{partitionKeyFromQuery:month}/day:!{partitionKeyFromQuery:day}/hour:!{partitionKeyFromQuery:hour}/"
    #    prefix = "data/device=!{partitionKeyFromQuery:device}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"

    processing_configuration {
      enabled = "true"

      # Multi-record deaggregation processor example
      processors {
        type = "RecordDeAggregation"
        parameters {
          parameter_name  = "SubRecordType"
          parameter_value = "JSON"
        }
      }

      # New line delimiter processor example
      processors {
        type = "AppendDelimiterToRecord"
      }

      # JQ processor example
      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{device:.device, year:.time | strptime(\"%Y-%m-%d %H:%M:%S\") | strftime(\"%Y\"), month: .time | strptime(\"%Y-%m-%d %H:%M:%S\") | strftime(\"%m\"), day: .time | strptime(\"%Y-%m-%d %H:%M:%S\") | strftime(\"%d\"), hour:.time | strptime(\"%Y-%m-%d %H:%M:%S\") | strftime(\"%H\")}"
          #          parameter_value = "{device:.device}"
        }
      }
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.aq_data_stream.arn
    role_arn           = aws_iam_role.iot_kinesis_s3_role.arn
  }
}

resource "aws_s3_bucket" "measurements_bucket" {
  bucket = "idealaq-aq-measurements-bucket"

  tags = {
    Name = "AQ measurements bucket"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket     = aws_s3_bucket.measurements_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}


#resource "aws_iam_policy" "data_stream_policy" {
#  name        = "data_stream_policy"
#  description = "Data Stream Policy"
#
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Action   = [
#          "kinesis:DescribeStream"
#        ],
#        Effect   = "Allow",
#        Resource = [
#          aws_kinesis_stream.aq_data_stream.arn
#        ]
#      }
#      # Add more statements as needed for other permissions
#    ]
#  })
#}


# https://stackoverflow.com/questions/76049290/error-accesscontrollistnotsupported-when-trying-to-create-a-bucket-acl-in-aws
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.measurements_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Kinesis -> S3 IAM:
resource "aws_iam_role" "iot_kinesis_s3_role" {
  name = "firehouse_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      },
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

# __

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

resource "aws_iam_role_policy_attachment" "kinesis_publish_policy_attachment" {
  policy_arn = aws_iam_policy.kinesis_publish_policy.arn
  role       = aws_iam_role.iot_kinesis_s3_role.name
}

# __

resource "aws_iam_policy" "firehose_publish_policy" {
  name        = "firehose_publish_policy"
  description = "Policy to allow publishing to Kinesis Delivery Stream"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"],
        Effect   = "Allow",
        Resource = aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn
      }
      # Add more statements as needed for other permissions
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_publish_policy_attachment" {
  role       = aws_iam_role.iot_kinesis_s3_role.name
  policy_arn = aws_iam_policy.firehose_publish_policy.arn
}

# __

resource "aws_iam_policy" "s3_publish_policy" {
  name        = "s3_publish_policy"
  description = "Policy to allow publishing to s3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.measurements_bucket.arn,
          "${aws_s3_bucket.measurements_bucket.arn}/*"
        ]
      }
      # Add more statements as needed for other permissions
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_publish_policy_attachment" {
  role       = aws_iam_role.iot_kinesis_s3_role.name
  policy_arn = aws_iam_policy.s3_publish_policy.arn
}

# __

resource "aws_iam_policy" "data_stream_consume_policy" {
  name        = "data_stream_policy"
  description = "Data Stream Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        Effect = "Allow",
        Resource = [
          aws_kinesis_stream.aq_data_stream.arn
        ]
      }
      # Add more statements as needed for other permissions
    ]
  })
}

resource "aws_iam_role_policy_attachment" "data_stream_consume_policy_attachment" {
  role       = aws_iam_role.iot_kinesis_s3_role.name
  policy_arn = aws_iam_policy.data_stream_consume_policy.arn
}

# __

