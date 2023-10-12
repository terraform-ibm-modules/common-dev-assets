#!/bin/bash
set -e

BASE_DIR=$(pwd)
search_dir=./examples
# run code for each example
for entry in "$search_dir"/*
do
    cd $entry
    TERRAFORM_DIR=.terraform
    # if .terraform folder exists then run terraform upgrade
    if [ -d "$TERRAFORM_DIR" ]; then
        terraform init -upgrade
    fi
    cd $BASE_DIR
done
