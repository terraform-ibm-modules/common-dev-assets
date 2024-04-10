#!/usr/bin/env bash

# Update the common-dev-assets subtree
output=$(git subtree pull --prefix common-dev-assets https://github.com/terraform-ibm-modules/common-dev-assets stacks --squash --force 2>&1)

# Check if the output contains the specific string using Bash string manipulation
if [[ "$output" == *"Subtree is already at commit"* ]]; then
  # Subtree is already up to date, exit successfully
  exit 0
else
  # Subtree update failed or made changes
  echo "common-dev-assets subtree update failed or made changes:"
  echo "$output"
  exit 1
fi
