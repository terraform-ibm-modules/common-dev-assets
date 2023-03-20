#!/usr/bin/env bash

# Pre-commit hook that checks if the license exists in the project with terraform files

# exit 0 if internal repo
if git remote -v | head -n 1 | grep -q "github.ibm"; then
  exit 0
fi

# exit 0 if no terraform files found in root directory
count=$(find ./*.tf 2>/dev/null | wc -l | xargs)
if [ "$count" != 0 ]; then
  if [[ ! -f "LICENSE" ]]; then
    echo "Required file LICENSE is missing. Please add it and try again."
    exit 1
  fi
fi
