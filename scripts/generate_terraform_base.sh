#!/bin/bash
# Generates the standard Terraform files if they do not already exist.

echo "Generating the following Terraform files: main.tf variables.tf outputs.tf providers.tf version.tf README.md"

if [ ! -f "main.tf" ]; then
  echo "  - main.tf created"
  cat << EOF > "main.tf"
##############################################################################
# Main Configuration
##############################################################################
EOF
else
  echo "  - main.tf already exists, skipping creation"
fi

if [ ! -f "variables.tf" ]; then
  echo "  - variables.tf created"
  cat << EOF > "variables.tf"
##############################################################################
# Input Variables
##############################################################################
EOF
else
  echo "  - variables.tf already exists, skipping creation"
fi

if [ ! -f "outputs.tf" ]; then
  echo "  - outputs.tf created"
  cat << EOF > "outputs.tf"
##############################################################################
# Outputs
##############################################################################
EOF
else
  echo "  - outputs.tf already exists, skipping creation"
fi

if [ ! -f "providers.tf" ]; then
  echo "  - providers.tf created"
  cat << EOF > "providers.tf"
##############################################################################
# Providers
##############################################################################
EOF
else
  echo "  - providers.tf already exists, skipping creation"
fi

if [ ! -f "version.tf" ]; then
  echo "  - version.tf created"
  cat << EOF > "version.tf"
##############################################################################
# Terraform Version
##############################################################################
EOF
else
  echo "  - version.tf already exists, skipping creation"
fi

if [ ! -f "README.md" ]; then
  echo "  - README.md created"
  cat << EOF > "README.md"
# Module

This is the documentation for the Terraform module.
EOF
else
  echo "  - README.md already exists, skipping creation"
fi

echo "Complete"
