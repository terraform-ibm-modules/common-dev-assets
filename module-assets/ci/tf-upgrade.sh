#!/bin/bash
set -e

BASE_DIR=$(pwd)
examples_dir=./examples
# run code for each example
for example in "$examples_dir"/*
do
    cd "$example"
    TERRAFORM_DIR=.terraform
    # if .terraform folder exists then run terraform upgrade
    if [ -d "$TERRAFORM_DIR" ]; then
        terraform init -upgrade
    fi
    cd "$BASE_DIR"
done
