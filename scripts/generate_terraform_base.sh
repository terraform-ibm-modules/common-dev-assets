#!/bin/bash
# Generates the standard Terraform files if they do not already exist.

echo "Generating the following Terraform files: main.tf variables.tf outputs.tf provider.tf version.tf README.md"

if [ ! -f "main.tf" ]; then
  echo "  - main.tf"
  cat << EOF > "main.tf"
##############################################################################
# Main Configuration
##############################################################################
EOF
else
  echo "  - main.tf already exists, skipping creation"
fi

if [ ! -f "variables.tf" ]; then
  echo "  - variables.tf"
  cat << EOF > "variables.tf"
##############################################################################
# Input Variables
##############################################################################
EOF
else
  echo "  - variables.tf already exists, skipping creation"
fi

if [ ! -f "outputs.tf" ]; then
  echo "  - outputs.tf"
  cat << EOF > "outputs.tf"
##############################################################################
# Outputs
##############################################################################
EOF
else
  echo "  - outputs.tf already exists, skipping creation"
fi

if [ ! -f "provider.tf" ]; then
  echo "  - provider.tf"
  cat << EOF > "provider.tf"
##############################################################################
# Provider
##############################################################################
EOF
else
  echo "  - provider.tf already exists, skipping creation"
fi

if [ ! -f "version.tf" ]; then
  echo "  - version.tf"
  cat << EOF > "version.tf"
##############################################################################
# Terraform Version
##############################################################################
EOF
else
  echo "  - version.tf already exists, skipping creation"
fi

if [ ! -f "README.md" ]; then
  echo "  - README.md"
  cat << EOF > "README.md"
# Module

This is the documentation for the Terraform module.
EOF
else
  echo "  - README.md already exists, skipping creation"
fi

echo "Complete"
