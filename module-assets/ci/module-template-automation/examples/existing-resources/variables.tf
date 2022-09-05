variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API Key"
  sensitive   = true
}

variable "vpc_name" {
  type        = string
  description = "The name of an existing VPC"
}

variable "region" {
  type        = string
  description = "Region where existing resources exist"
}
