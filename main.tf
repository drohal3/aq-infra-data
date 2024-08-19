########################################################################################################################
## TODO: https://silvr.medium.com/aws-timestream-with-terraform-259eaa9960d1
#
########################################################################################################################
variable "region" {
  description = "The AWS region to deploy the resources"
  default     = "eu-central-1"
  type        = string
}

variable "iot_topic" {
  description = "The MQTT topic for IoT Core"
  default     = "aq/measurement"
  type        = string
}

provider "aws" {
  region = var.region
}

#######################################################################################################################
#######################################################################################################################
## IoT Policy ====>
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
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topic/${var.iot_topic}",
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topic/aq/test"
        ]
      },
      {
        Action = [
          "iot:Connect"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:client/aq*Client",
        ]
      },
      {
        Action = [
          "iot:Subscribe"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topicfilter/${var.iot_topic}",
          "arn:aws:iot:${var.region}:${data.aws_caller_identity.current.account_id}:topicfilter/aq/test"
        ]
      }
      # Add more statements as needed for other permissions
    ]
  })
}

data "aws_caller_identity" "current" {}

# ### certificates
#######################################################################################################################
# Test Client
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
  value     = aws_iot_certificate.iot_cert.certificate_pem
  sensitive = true
}

output "private_key" {
  value     = aws_iot_certificate.iot_cert.private_key
  sensitive = true
}

output "public_key" {
  value     = aws_iot_certificate.iot_cert.public_key
  sensitive = true
}

#######################################################################################################################
# Gateway 1 Client
resource "aws_iot_thing" "iot_thing_gateway_1" {
  name = "Gateway1Thing"
}

resource "aws_iot_certificate" "iot_cert_gateway_1" {
  active = true
}

resource "aws_iot_policy_attachment" "iot_policy_attachment_gateway_1" {
  policy = aws_iot_policy.aq_data_iot_core_policy.name
  target = aws_iot_certificate.iot_cert_gateway_1.arn
}

resource "aws_iot_thing_principal_attachment" "iot_thing_attachment_gateway_1" {
  thing     = aws_iot_thing.iot_thing_gateway_1.name
  principal = aws_iot_certificate.iot_cert_gateway_1.arn
}

output "certificate_arn_gateway_1" {
  value = aws_iot_certificate.iot_cert_gateway_1.arn
}

output "certificate_pem_gateway_1" {
  value     = aws_iot_certificate.iot_cert_gateway_1.certificate_pem
  sensitive = true
}

output "private_key_gateway_1" {
  value     = aws_iot_certificate.iot_cert_gateway_1.private_key
  sensitive = true
}

output "public_key_gateway_1" {
  value     = aws_iot_certificate.iot_cert_gateway_1.public_key
  sensitive = true
}

#######################################################################################################################
#######################################################################################################################

variable "expected_devices" {
  description = "Expected number of devices publishing data per second."
  type        = number
  default     = 1 # Adjust as needed! <=== <=== <===
}

#######################################################################################################################

module "dynamodb_option" {
  source         = "./modules/dynamodb_option"
  iot_topic      = var.iot_topic
  write_capacity = var.expected_devices
}

#module "timestream_option" {
#  source    = "./modules/timestream_option"
#  iot_topic = var.iot_topic
#}
#
#module "datastreams_option" {
#  source    = "./modules/datastreams_option"
#  iot_topic = var.iot_topic
#}