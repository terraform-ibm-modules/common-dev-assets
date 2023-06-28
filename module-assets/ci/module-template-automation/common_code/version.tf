terraform {
  # Since hashicorp can include breaking changes in minor version updates, ensure to lock into a range here.
  required_version = ">= 1.3, < 1.6"

  # Use a flexible range in modules that future proofs the module's usage with upcoming minor and patch versions
  #  required_providers {
  #    ibm = {
  #      source  = "IBM-Cloud/ibm"
  #      version = ">= 1.49.0, < 2.0.0"
  #    }
  #  }
}
