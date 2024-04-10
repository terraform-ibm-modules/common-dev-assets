#!/bin/sh

# Update the common-dev-assets subtree
git subtree pull --prefix common-dev-assets https://github.com/terraform-ibm-modules/common-dev-assets stacks --squash

# Check if the subtree update made any changes
if git diff-index --quiet HEAD --; then
  # No changes made by the subtree update
  exit 0
else
  # Changes made by the subtree update
  echo "common-dev-assets subtree has changes. Please run pre-commit again"
  exit 1
fi
