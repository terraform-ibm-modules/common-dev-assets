# Sample Terraform snippet to allow the terraform fmt and lint hooks to be executed.

resource "ibm_is_vpc" "vpc" {
  name                      = "${var.unique_name}-vpc"
  resource_group            = var.resource_group_id
  default_network_acl_name  = "${var.unique_name}-edge-acl"
  address_prefix_management = "manual"
  tags                      = var.vpc_tags
}
