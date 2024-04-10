#!/bin/sh

# Update the common-dev-assets subtree
git subtree pull --prefix common-dev-assets https://github.com/terraform-ibm-modules/common-dev-assets stacks --squash

# Add subtree changes
git add common-dev-assets

# if any changes exit with error code 1
if [ -n "$(git status --porcelain)" ]; then
  echo "common-dev-assets subtree has changes. Please run pre-commit again"
  exit 1
fi
