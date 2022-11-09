#!/usr/bin/python

import glob
import os
import sys
from pathlib import Path
from subprocess import PIPE, Popen


def terraform_init():
    tf_init_command = "terraform init"
    proc = Popen(tf_init_command, stdout=PIPE, stderr=PIPE, shell=True)
    proc.communicate()
    return proc.returncode


def terraform_init_upgrade():
    tf_init_upgrade_command = "terraform init --upgrade"
    proc = Popen(tf_init_upgrade_command, stdout=PIPE, stderr=PIPE, shell=True)
    error = proc.communicate()
    if proc.returncode != 0:
        print(error)
        sys.exit(proc.returncode)


def get_terraform_provider():
    for terraform_provider in Path(".terraform").rglob("provider_metadata.json"):
        return terraform_provider


def run_metadata_generator(file_path, terraform_provider):
    if terraform_provider:
        os.system(
            "terraform-config-inspect --json > %s --metadata %s"
            % (file_path, terraform_provider)
        )
    else:
        os.system("terraform-config-inspect --json > %s" % (file_path))


def main():
    if glob.glob("*.tf"):
        # always run terraform init
        error_code = terraform_init()

        # if error then try terraform init upgrade
        if error_code != 0:
            terraform_init_upgrade()

        # get IBM terraform provider
        terraform_provider = get_terraform_provider()

        # run metadata generator tool
        metadata_name = "module-metadata.json"
        run_metadata_generator(metadata_name, terraform_provider)


main()
