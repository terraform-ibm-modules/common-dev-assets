#!/usr/bin/python

import os
import subprocess
from subprocess import PIPE, Popen


def create_tf_input(module_name):
    print(module_name)
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
            "common-dev-assets/module-assets/.terraform-docs-config-template-module.yaml",
            ".",
        ],
        check=True,
    )


def remove_tf_input(module_name):
    if os.path.exists("%s.tf" % (module_name)):
        os.remove("%s.tf" % (module_name))


def main():
    # get repository name
    my_command = "basename `git rev-parse --show-toplevel`"
    proc = Popen(my_command, stdout=PIPE, stderr=PIPE, shell=True)
    output, error = proc.communicate()
    module_name = output.decode("utf-8").strip()

    if proc.returncode != 0:
        print(error)
    elif module_name == "module-template":  # module-template
        create_tf_input(module_name)
        run_terraform_docs()
        remove_tf_input(module_name)


main()
