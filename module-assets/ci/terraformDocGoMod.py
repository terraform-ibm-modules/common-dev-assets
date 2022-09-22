#!/usr/bin/python

import re
import sys
from pathlib import Path
from subprocess import PIPE, Popen
from urllib.parse import urlparse


# Set go.mod file with the correct module repo
def set_go_mod(path, module_url):
    with open(path, "r") as file:
        lines = file.readlines()
    if len(lines) > 0:
        expected_line = "module " + module_url
        replace_module = False
        for index, line in enumerate(lines):
            regex = re.search(r"module.*?github.*?", line)
            if regex:
                regex_result = regex.string.strip()
                if regex_result.lower() != expected_line.lower():
                    replace_module = True
                    break
        if replace_module:
            lines[index] = expected_line + "\n"
            with open(path, "w") as writer:
                writer.writelines(lines)


# get repository url
def get_module_url():
    get_repository_url_command = "git config --get remote.origin.url"
    proc = Popen(get_repository_url_command, stdout=PIPE, stderr=PIPE, shell=True)
    output, error = proc.communicate()
    full_url = output.decode("utf-8").strip()

    if proc.returncode != 0:
        print(error)
        sys.exit(proc.returncode)

    # urlparse can not be used for git urls
    if full_url.startswith("http"):
        output = urlparse(full_url)
        module_url = output.hostname + output.path
    else:
        module_url = full_url.replace("git@", "").replace(":", "/")

    return module_url.replace(".git", "")


def main():
    go_mod_path = Path("tests/go.mod")
    if go_mod_path.is_file():
        module_url = get_module_url()
        if module_url:
            set_go_mod(go_mod_path, module_url)


main()
