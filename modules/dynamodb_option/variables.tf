variable "read_capacity" {
  description = "read capacity"
  type = number
  default = 1
}

variable "write_capacity" {
  description = "write capacity"
  type = number
  default = 1
}

variable "iot_topic" {
  description = "The MQTT topic for IoT Core"
  type = string
}

variable "table_name" {
  description = "Name of DynamoDB table"
  type = string
}

variable "name" {
  default = "Unique name"
  type = string
}

variable "tags" {
  description = "Tags"
  type = map(string)
}