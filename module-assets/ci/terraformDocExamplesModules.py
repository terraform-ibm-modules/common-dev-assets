#!/usr/bin/python

import os
from pathlib import Path


# Return title (first line) of README file
def get_readme_title(readme_file):
    with open(readme_file, "r") as reader:
        line = reader.readline()
        return line


# check if folder contains any tf file
def has_tf_files(path):
    if any(File.endswith(".tf") for File in os.listdir(path)):
        return True
    else:
        return False


# Return titles of all README files inside examples folder.
def get_readme_titles(path):
    readme_titles = []
    for readme_file in Path(path).rglob("README.md"):
        path = str(readme_file)
        # ignore README file if it has dot(.) in a path or the parent path does not contain any tf file
        if not ("/.") in path and has_tf_files(readme_file.parent):
            readme_title = get_readme_title(path)
            if readme_title:
                data = {"path": path, "title": readme_title}
                readme_titles.append(data)
    readme_titles.sort(key=lambda x: x["path"])
    return readme_titles


def prepare_lines(readme_titles, newlines, default_line):
    if len(readme_titles) > 0:
        # newlines = []
        for readme_title in readme_titles:
            prepare_line = (
                "- ["
                + readme_title["title"].strip().replace("#", "")
                + "]("
                + readme_title["path"].replace("/README.md", "")
                + ")\n"
            )
            newlines.append(prepare_line)
    else:
        newlines.append(default_line)


def create_markdown(newlines, markdown):
    with open(markdown, "w") as writer:
        if len(newlines) > 0:
            for line in newlines:
                writer.writelines(line)


def remove_markdown(markdown):
    if os.path.exists(markdown):
        os.remove(markdown)


def is_hook_exists(hook_tag):
    exists = False
    with open("README.md", "r") as reader:
        lines = reader.readlines()
        for line in lines:
            if hook_tag in line:
                exists = True
    return exists


def add_examples():
    examples_hook_tag = "BEGIN EXAMPLES HOOK"
    # continue if examples folder exists and if README has examples hook tag
    if os.path.isdir("examples") and is_hook_exists(examples_hook_tag):
        newlines = []
        readme_titles = get_readme_titles("examples")
        default_line = "- [Examples](examples)\n"
        examples_markdown = "EXAMPLES.md"
        # prepare lines to be added to README examples section
        prepare_lines(readme_titles, newlines, default_line)
        # create github markdown file
        create_markdown(newlines, examples_markdown)
        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-examples.yaml ."
        )
        remove_markdown(examples_markdown)


def add_modules():
    modules_hook_tag = "BEGIN TF SUBMODULES HOOK"
    # continue if modules folder exists and if README has modules hook tag
    if os.path.isdir("modules") and is_hook_exists(modules_hook_tag):
        newlines = []
        readme_titles = get_readme_titles("modules")
        default_line = "- [Modules](modules)\n"
        modules_markdown = "MODULES.md"
        # prepare lines to be added to README modules section
        prepare_lines(readme_titles, newlines, default_line)
        # create github markdown file
        create_markdown(newlines, modules_markdown)
        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-modules.yaml ."
        )
        remove_markdown(modules_markdown)


def main():
    add_examples()
    add_modules()


main()
