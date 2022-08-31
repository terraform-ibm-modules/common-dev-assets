#!/bin/bash
set -e

tf_files=()
while IFS='' read -r line; do tf_files+=("$line"); done < <(find ./ -name "*.tf" -maxdepth 1)

if [ ${#tf_files[@]} -gt 0 ]; then
   terraform-config-inspect --json > module-metadata.json
fi
