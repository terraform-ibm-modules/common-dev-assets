#!/usr/bin/env bash

# Pre-commit hook that checks if the license exists in the project with terraform files

# Won't run if repo is internal
if git remote -v | head -n 1 | grep -q "github.ibm"; then
    echo "internal repo"
    exit 0
fi

count=$(find ./*.tf 2>/dev/null | wc -l)
if [ "$count" != 0 ]; then
  exit 1
fi

if [[ ! -f "LICENSE" ]]; then
    echo "Required file LICENSE is missing."
    exit 1
fi
