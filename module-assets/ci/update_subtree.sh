#!/bin/sh

# Update the common-dev-assets subtree
git subtree pull --prefix common-dev-assets https://github.com/terraform-ibm-modules/common-dev-assets stacks --squash

# Add subtree changes
git add common-dev-assets
