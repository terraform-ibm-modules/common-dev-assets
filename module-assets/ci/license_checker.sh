#!/usr/bin/env bash

# Pre-commit hook that checks if the license exists in the project with terraform files

regex=' [^//]*.tf '
if [[ ! "'$*'" =~ $regex ]]; then
    exit 0
fi

if [[ ! -f "LICENSE" ]]; then
    echo "Required file LICENSE is missing."
    exit 1
fi
