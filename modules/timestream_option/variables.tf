variable "iot_topic" {
  description = "The MQTT topic for IoT Core"
  type = string
}

variable "table_name" {
  description = "Name of Timestream table"
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