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
}