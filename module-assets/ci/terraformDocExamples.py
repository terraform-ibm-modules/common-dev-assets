#!/usr/bin/python

import os
from pathlib import Path

examples_markdown = "EXAMPLES.md"


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
def get_readme_titles():
    readme_titles = []
    for readme_file in Path("examples").rglob("README.md"):
        path = str(readme_file)
        # ignore README file if it has dot(.) in a path or the parent path does not contain any tf file
        if not ("/.") in path and has_tf_files(readme_file.parent):
            readme_title = get_readme_title(path)
            if readme_title:
                data = {"path": path, "title": readme_title}
                readme_titles.append(data)
    readme_titles.sort(key=lambda x: x["path"])
    return readme_titles


def prepare_example_lines(readme_titles, newlines):
    if len(readme_titles) > 0:
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
        prepare_line = "- [Examples](examples)\n"
        newlines.append(prepare_line)


def create_examples_markdown(newlines):
    with open(examples_markdown, "w") as writer:
        if len(newlines) > 0:
            for line in newlines:
                writer.writelines(line)


def run_terraform_docs():
    os.system(
        "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config.yaml ."
    )


def remove_examples_markdown():
    if os.path.exists(examples_markdown):
        os.remove(examples_markdown)


def is_examples_hook_exists():
    exists = False
    with open("README.md", "r") as reader:
        lines = reader.readlines()
        for line in lines:
            if "BEGIN EXAMPLES HOOK" in line:
                exists = True
    return exists


def main():
    if os.path.isdir("examples") and is_examples_hook_exists():
        newlines = []
        readme_titles = get_readme_titles()
        prepare_example_lines(readme_titles, newlines)
        create_examples_markdown(newlines)
        run_terraform_docs()
        remove_examples_markdown()


main()
