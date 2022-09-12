#!/usr/bin/python

import os
import shutil
import subprocess
from subprocess import PIPE, Popen


def create_tf_input(module_name):
    file = open("%s.tf" % (module_name), "w+")
    file.write(
        """
        variable "%s" {
            type = string
        }
    """
        % (module_name)
    )
    file.close()


def run_terraform_docs():
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/ci/module-template-automation/.terraform-docs-config-template-module.yaml",
            ".",
        ],
        check=True,
    )
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/ci/module-template-automation/.terraform-docs-config-template-module-contribution.yaml",
            ".",
        ],
        check=True,
    )
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/ci/module-template-automation/.terraform-docs-config-template-module-tests.yaml",
            ".",
        ],
        check=True,
    )


def copy_common_code():
    shutil.copytree(
        "ci/module-template-automation/examples", "examples", dirs_exist_ok=True
    )
    shutil.copytree(
        "ci/module-template-automation/common_code", "./", dirs_exist_ok=True
    )
    shutil.copytree("ci/module-template-automation/tests", "tests", dirs_exist_ok=True)


def remove_tf_input(module_name):
    if os.path.exists("%s.tf" % (module_name)):
        os.remove("%s.tf" % (module_name))


def main():
    # get repository name
    get_repository_name_command = "basename `git config --get remote.origin.url`"
    proc = Popen(get_repository_name_command, stdout=PIPE, stderr=PIPE, shell=True)
    output, error = proc.communicate()
    module_name = output.decode("utf-8").strip().replace(".git", "")

    if proc.returncode != 0:
        print(error)
    elif (
        module_name == "module-template"
        or module_name == "terraform-ibm-module-template"
    ):
        copy_common_code()
        create_tf_input(module_name)
        run_terraform_docs()
        remove_tf_input(module_name)


main()
