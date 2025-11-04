#!/bin/bash

set -euo pipefail

echo "Starting Trivy scan..."

find . -type f -name 'go.mod' -print0 |
while IFS= read -r -d '' modfile; do
  # skip hidden paths and common-dev-assets
  if [[ "$modfile" == *"/."* || "$modfile" == *"common-dev-assets"* ]]; then
    continue
  fi

  dir=$(dirname "$modfile")
  echo "Scanning: $dir"
  trivy fs "$dir" --severity HIGH,CRITICAL --exit-code 1
done
