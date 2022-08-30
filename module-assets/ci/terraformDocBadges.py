#!/usr/bin/python

import subprocess
from subprocess import PIPE, Popen


def run_terraform_docs():
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/.terraform-docs-config-batch.yaml",
            ".",
        ],
        check=True,
    )


def main():
    # get repository name
    my_command = "basename `git rev-parse --show-toplevel`"
    proc = Popen(my_command, stdout=PIPE, stderr=PIPE, shell=True)
    output, error = proc.communicate()
    project_name = output.decode("utf-8").strip()
    print(project_name)

    if proc.returncode != 0:
        print(error)
    elif project_name == "module-template":  # module-template
        run_terraform_docs()


main()
