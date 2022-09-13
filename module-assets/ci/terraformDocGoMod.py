#!/usr/bin/python

import sys
from pathlib import Path
from subprocess import PIPE, Popen


# Set go.mod file with the correct module repo
def set_go_mod(path, module_url):
    with open(path, "r") as file:
        lines = file.readlines()
    if lines:
        first_line = lines[0]
        expected_line = "module " + module_url
        if first_line.strip() != expected_line:
            lines[0] = expected_line + "\n"
            with open(path, "w") as writer:
                writer.writelines(lines)


# get repository url
def get_module_url():
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
        sys.exit(proc.returncode)
    else:
        return module_url


def main():
    go_mod_path = Path("tests/go.mod")
    if go_mod_path.is_file():
        module_url = get_module_url()
        if module_url:
            set_go_mod(go_mod_path, module_url)


main()
