terraform {
  # Since hashicorp can include breaking changes in minor version updates, ensure to lock into a range here.
  required_version = ">= 1.3, < 1.6"

  # Ensure that there is always 1 example locked into the lowest provider version of the range defined in the main
  # module's version.tf (usually a basic example), and 1 example that will always use the latest provider version.
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.49.0"
    }
  }
}
