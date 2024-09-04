variable "iot_topic" {
  description = "The MQTT topic for IoT Core"
  type = string
}

variable "tags" {
  description = "Tags"
  type = map(string)
}