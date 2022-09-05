##############################################################################
# Outputs
##############################################################################

output "region" {
  description = "Region"
  value       = var.region
}

output "prefix" {
  description = "Prefix"
  value       = var.prefix
}

output "resource_group_name" {
  description = "RG name"
  value       = var.resource_group
}

output "resource_tags" {
  description = "Tags"
  value       = var.resource_tags
}
