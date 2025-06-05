#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IGNORE_FILE="$SCRIPT_DIR/.codespell-ignores"

if [ -f "$IGNORE_FILE" ]; then
    exec codespell --ignore-words="$IGNORE_FILE" "$@"
else
    exec codespell "$@"
fi
