#!/usr/bin/python

import os
import subprocess
from pathlib import Path
from subprocess import PIPE, Popen


def create_tf_input(file_name, module_url):
    file = open("%s.tf" % (file_name), "w+")
    file.write(
        """
        variable "%s" {
            type = string
            description = "%s"
        }
    """
        % (file_name, module_url)
    )
    file.close()


def run_terraform_docs():
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/.terraform-docs-config-go-mod.yaml",
            ".",
        ],
        check=True,
    )


def remove_tf_input(file_name):
    if os.path.exists("%s.tf" % (file_name)):
        os.remove("%s.tf" % (file_name))


# Check if go.mod file already have a pre-commit hook metadata tag. If not, replace the first line with a metadata tag
def check_go_mod(path):

    with open(path, "r") as file:
        lines = file.readlines()

    first_line = lines[0]
    if first_line.strip() == "// START MODULE NAME HOOK":
        return
    else:
        lines[0] = "// START MODULE NAME HOOK\n// END MODULE NAME HOOK\n"
        with open(path, "w") as writer:
            writer.writelines(lines)


def main():
    go_mod_path = Path("tests/go.mod")
    if go_mod_path.is_file():
        tf_inputs_temp_file = "tf_inputs_temp_file"

        # get repository url
        get_repository_url_command = "git config --get remote.origin.url"
        proc = Popen(get_repository_url_command, stdout=PIPE, stderr=PIPE, shell=True)
        output, error = proc.communicate()
        module_url = (
            output.decode("utf-8")
            .strip()
            .replace(".git", "")
            .replace("git@", "")
            .replace("https://", "")
            .replace(":", "/")
        )

        if proc.returncode != 0:
            print(error)
            return

        check_go_mod(go_mod_path)
        create_tf_input(tf_inputs_temp_file, module_url)
        run_terraform_docs()
        remove_tf_input(tf_inputs_temp_file)


main()
