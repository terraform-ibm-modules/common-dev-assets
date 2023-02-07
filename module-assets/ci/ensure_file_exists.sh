#!/usr/bin/env bash

# Pre-commit hook that checks certain files exist in the project

# check that all files specified exist in root of project
for filename in "$@"; do
    if [[ ! -f "$filename" ]]; then
        echo "Required file $filename is missing."
        exit 1
    fi
done
