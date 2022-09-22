#!/usr/bin/python

import glob
import json
import os
import sys
from pathlib import Path


def run_metadata_generator(file_path, terrraform_provider):
    os.system(
        "terraform-config-inspect --json > %s --metadata %s --filter-variables"
        % (file_path, terrraform_provider)
    )


def open_file(file):
    with open(file, "r") as data:
        return json.load(data)


def write_object(data, path):
    json_data = json.dumps(data, indent=2)
    with open(path, "w") as outfile:
        outfile.write(json_data)


def ordered(obj):
    if isinstance(obj, dict):
        return sorted((k, ordered(v)) for k, v in obj.items())
    if isinstance(obj, list):
        return sorted(ordered(x) for x in obj)
    else:
        return obj


def remove_file(path):
    if os.path.exists(path):
        os.remove(path)


def get_terraform_provider():
    for terraform_provider in Path(".terraform").rglob("provider_metadata.json"):
        return terraform_provider


def main():
    if glob.glob("*.tf"):
        metadata_path_original = "module-metadata.json"
        metadata_path_temp = "module-metadata_temp.json"

        terraform_provider = get_terraform_provider()
        if terraform_provider:
            run_metadata_generator(metadata_path_temp, terraform_provider)

            # if module-metadata already exists then compare with a new data, otherwise save new data into module-metadata
            if os.path.exists(metadata_path_original):
                metadata_old_json = open_file(metadata_path_original)
                metadata_new_json = open_file(metadata_path_temp)

                # if objects are not equal then create module-metada with new content
                if ordered(metadata_old_json) != ordered(metadata_new_json):
                    write_object(metadata_new_json, metadata_path_original)
            else:
                metadata_new_json = open_file(metadata_path_temp)
                write_object(metadata_new_json, metadata_path_original)

            remove_file(metadata_path_temp)
        else:
            print("Error: Terraform provider does not exists.")
            sys.exit(1)


main()
