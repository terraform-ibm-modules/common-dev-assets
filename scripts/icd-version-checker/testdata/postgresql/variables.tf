##############################################################################
# Input Variables
##############################################################################

variable "resource_group_id" {
  type        = string
  description = "The resource group ID where the PostgreSQL instance will be created."
}

variable "name" {
  type        = string
  description = "The name to give the Postgresql instance."
}

variable "postgresql_version" {
  type        = string
  description = "Version of the PostgreSQL instance. If no value is passed, the current preferred version of IBM Cloud Databases is used."
  default     = null

  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "17",
      var.postgresql_version == "16",
      var.postgresql_version == "15",
      var.postgresql_version == "14",
      var.postgresql_version == "13",
    ])
    error_message = "Version must be 13, 14, 15, 16 or 17. If no value passed, the current ICD preferred version is used."
  }
}

variable "region" {
  type        = string
  description = "The region where you want to deploy your instance."
  default     = "us-south"
}
