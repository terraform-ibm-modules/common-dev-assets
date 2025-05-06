# Sample Terraform snippet to allow the terraform fmt and lint hooks to be executed.

resource "ibm_is_vpc" "vpc" {
  name                      = "${var.unique_name}-vpc"
  resource_group            = var.resource_group_id
  default_network_acl_name  = "${var.unique_name}-edge-acl"
  address_prefix_management = "manual"
  tags                      = var.vpc_tags
}

# add resource for trivy to catch errors with dynamic block
resource "ibm_is_security_group_rule" "security_group_rules" {
  group     = "group_id"
  direction = "inbound"
  remote    = "127.0.0.1"
  dynamic "icmp" {
    for_each = var.rules
    content {
      type = "30"
      code = "20"
    }
  }
}
