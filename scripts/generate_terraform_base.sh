#!/bin/bash
# Generates the standard terraform files for a module or submodule.

echo "Generating the following files: main.tf, variables.tf, outputs.tf, provider.tf, version.tf, README.md"

cat << EOF > main.tf
##############################################################################
# Main Configuration
##############################################################################
EOF

cat << EOF > variables.tf
##############################################################################
# Input Variables
##############################################################################
EOF

cat << EOF > outputs.tf
##############################################################################
# Outputs
##############################################################################
EOF

cat << EOF > provider.tf
##############################################################################
# Provider
##############################################################################
EOF

cat << EOF > version.tf
##############################################################################
# Terraform Version
##############################################################################
EOF

cat << EOF > README.md
# Module

This is the documentation for the Terraform module.
EOF

echo "Complete"
