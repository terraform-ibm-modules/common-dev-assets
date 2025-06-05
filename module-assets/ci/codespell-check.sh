#!/bin/bash

if [ -f "common-dev-assets/.codespell-ignores" ]; then
    exec codespell --ignore-words=.codespell-ignores "$@"
else
    exec codespell "$@"
fi