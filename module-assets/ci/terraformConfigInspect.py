#!/usr/bin/python

import glob
import os
import sys
from pathlib import Path


def terraform_init():
    os.system("terraform init -upgrade")


def get_terraform_provider():
    for terraform_provider in Path(".terraform").rglob("provider_metadata.json"):
        return terraform_provider


def run_metadata_generator(file_path, terrraform_provider):
    os.system(
        "terraform-config-inspect --json > %s --metadata %s --filter-variables"
        % (file_path, terrraform_provider)
    )


def main():
    if glob.glob("*.tf"):

        terraform_init()

        terraform_provider = get_terraform_provider()

        if terraform_provider:
            metadata_name = "module-metadata.json"
            run_metadata_generator(metadata_name, terraform_provider)
        else:
            print("Error: Terraform provider does not exists.")
            sys.exit(1)


main()
