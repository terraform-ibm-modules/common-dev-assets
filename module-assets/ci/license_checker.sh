#!/usr/bin/env bash

# Pre-commit hook that checks if the license exists in the project with terraform files

# exit 0 if internal repo
if git remote -v | head -n 1 | grep -q "github.ibm"; then
  exit 0
fi


# ensure LICENSE file exists if .tf file or ibm_catalog.json is detected in root directory

var1=$(find ./*.tf 2>/dev/null | wc -l | xargs)
var2=$(find ibm_catalog.json 2>/dev/null | wc -l | xargs)
count=$((var1+var2))
if [ "$count" != 0 ]; then
  if [[ ! -f "LICENSE" ]]; then
    echo "Required LICENSE file is missing. Please add it and try again."
    exit 1
  fi
fi
