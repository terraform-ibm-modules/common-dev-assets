#!/usr/bin/python

import re
from pathlib import Path

import ruamel.yaml as yaml
import terraformDocsUtils


# Set go.mod file with the correct module repo
def set_go_mod(path: str, module_url: str):
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


# modify module url to internal or external repo
def change_module_url(module_url: str) -> str:
    git_owner = "terraform-ibm-modules"
    if "github.ibm.com" in module_url:
        git_owner = "GoldenEye"
    return re.sub(
        "/.*/",
        lambda x: x.group(0).replace(x.group(0), "/%s/" % (git_owner)),
        module_url,
    )


# read repo name from .github/settings.yml file
def get_repo_name():
    repo_name = ""
    with open(".github/settings.yml", "r") as file:
        prime_service = yaml.safe_load(file)
        repo_name = prime_service["repository"]["name"]
    return repo_name


# replace repo name from git config to value which is inside .github/settings.yml.
# With that we prevent a script to fail in a case that repo name has been changed. See https://github.ibm.com/goldeneye/issues/issues/5937
def replace_repo_name(repo_name: str, module_url: str) -> str:
    new_module_url = ""
    if repo_name and module_url:
        pos = module_url.rfind("/")
        new_module_url = module_url[: pos + 1] + repo_name
    return new_module_url


def main():
    go_mod_path = Path("tests/go.mod")
    if go_mod_path.is_file():
        module_url = change_module_url(terraformDocsUtils.get_module_url())
        repo_name = get_repo_name()
        replaced_url = replace_repo_name(repo_name, module_url)
        if replaced_url:
            set_go_mod(go_mod_path, replaced_url)


main()
