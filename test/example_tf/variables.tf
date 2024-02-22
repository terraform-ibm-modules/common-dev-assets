# Variables
variable "unique_name" {
  description = "A unique identifier used as a prefix when naming resources that will be provisioned. Must begin with a letter."
  type        = string
  default     = "asset-multizone"
}

variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
  type        = string
}

variable "resource_group_id" {
  description = "ID of resource group to use when creating the VPC"
  type        = string
}

variable "vpc_tags" {
  type        = list(string)
  description = "Any tags that you want to associate with your VPC."
  default     = []
}

variable "ibmcloud_api_key" {
  description = "API key that's associated with the account to use, set via environment variable TF_VAR_ibmcloud_api_key"
  type        = string
  sensitive   = true
}
