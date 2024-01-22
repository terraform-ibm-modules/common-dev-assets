#!/usr/bin/python

import os
import sys
from pathlib import Path
from subprocess import PIPE, Popen

import terraformDocsUtils


def modify_temp_markdown_files(temp_markdown):
    # temp markdowns
    markdown = "tf-docs.md"
    temp_markdowns = []

    # Find all previously generated temp markdowns and modify them
    for root, dirnames, filenames in os.walk("."):
        for name in filenames:
            if name == temp_markdown:
                # get full markdowns path
                markdown_path = os.path.join(root, temp_markdown)
                new_markdown_path = os.path.join(root, markdown)

                # save all temp markdowns for later to be delete it
                temp_markdowns.append(markdown_path)
                temp_markdowns.append(new_markdown_path)

                # change headings from lvl 2 to lvl 3 and save tf docs content into new temp file
                with open(markdown_path, "rt") as reader:
                    with open(new_markdown_path, "wt") as writer:
                        for line in reader:
                            # recursive flag adds BEGIN_TF_DOCS and END_TF_DOCS metatags to a markdown content by default. We do not need this, since we have own metatag
                            if not ("BEGIN_TF_DOCS" in line or "END_TF_DOCS" in line):
                                writer.write(line.replace("##", "###"))
    return temp_markdowns


# Check if README has pre-commit hook metadata
def has_pre_commit_hook_metadata(readme_file):
    has_metadata = False
    with open(readme_file, "r") as reader:
        for line in reader:
            if "<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->" in line:
                has_metadata = True
                break
    return has_metadata


# Find all subfolders that has README.md and contains PRE-COMMIT-TERRAFORM DOCS HOOK
def find_subfolders():
    subfolders = {}
    dir = os.getcwd()
    for readme_file in Path(dir).rglob("README.md"):
        path = str(readme_file)
        if not ("/.") in path and has_pre_commit_hook_metadata(readme_file):
            # extract subfolder name
            subfolder = str(readme_file.parent).replace(f"{dir}/", "").split("/")[0]
            if subfolder != "":
                subfolders[subfolder] = subfolder
    return subfolders.keys()


def update_docs():
    # temp markdown name
    temp_markdown = "temp-tf-docs.md"

    # list of temporary markdown files
    temp_markdowns = []

    # list of subfolders to be scanned and modified by tf_docs
    subfolders = find_subfolders()

    for subfolder in subfolders:
        # if subfolder exists then use recursive flag to check for changes inside subfolder
        subfolder_exists = os.path.isdir(subfolder)
        if subfolder_exists:
            # create temp markdowns for all README tf docs inside subfolder
            command = f"terraform-docs --hide providers markdown table --recursive --recursive-path {subfolder} --output-file {temp_markdown} ."
            proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
            proc.communicate()

            # hard fail if error
            if proc.returncode != 0:
                print(f"Error creating temp markdowns: {proc.communicate()[1]}")
                sys.exit(proc.returncode)

            # modify temp markdown files
            temp_markdowns = modify_temp_markdown_files(temp_markdown)

            # add temp markdown content to README files
            command = f"terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config.yaml --recursive --recursive-path {subfolder} ."
            proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
            proc.communicate()

            # hard fail if error
            if proc.returncode != 0:
                print(f"Error adding content to README: {proc.communicate()[1]}")
                for markdown in temp_markdowns:
                    terraformDocsUtils.remove_markdown(markdown)
                sys.exit(proc.returncode)

    # if any subfolder does not exist, then we need to run tf docs on main README root. If subfolder exists, then main README root is already scanned as a part of a recursive flag
    if not subfolders:
        # create temp markdowns for all README tf docs inside subfolder
        command = f"terraform-docs --hide providers markdown table --output-file {temp_markdown} ."
        proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
        proc.communicate()

        # hard fail if error
        if proc.returncode != 0:
            print(f"Error creating temp markdowns: {proc.communicate()[1]}")
            sys.exit(proc.returncode)

        # modify temp markdown files
        temp_markdowns = modify_temp_markdown_files(temp_markdown)

        # add temp markdown content to README files
        command = "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config.yaml ."
        proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
        proc.communicate()

        # hard fail if error
        if proc.returncode != 0:
            print(f"Error adding content to README: {proc.communicate()[1]}")
            for markdown in temp_markdowns:
                terraformDocsUtils.remove_markdown(markdown)
            sys.exit(proc.returncode)

    # remove all temp markdowns
    for markdown in temp_markdowns:
        terraformDocsUtils.remove_markdown(markdown)


def main():
    if terraformDocsUtils.is_hook_exists(
        "<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->"
    ):
        update_docs()


main()
