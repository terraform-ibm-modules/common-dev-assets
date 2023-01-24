#!/usr/bin/env bash

# Script for a pre-commit hook that prevents specified file change or deletion. (Allows addition)

for i in "$@"; do
    if git diff --cached --name-only --diff-filter=a |
        grep --quiet --line-regexp --fixed-strings "$i"
    then
        echo Commit would modify one or more files that must not change.
        exit 1
    else
        exit 0
    fi
done
