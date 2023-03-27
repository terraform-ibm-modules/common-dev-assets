##############################################################################
# Outputs
##############################################################################

output "cos_instance_id" {
  description = "COS instance id"
  value       = ibm_resource_instance.cos_instance.id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = module.resource_group.resource_group_name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = module.resource_group.resource_group_id
}
