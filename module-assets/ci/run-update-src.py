#!/usr/bin/env python3

# This script is to update module source references to hashicorp registry

import glob
import os
import re

import git
import requests

###########################################################################################################
# Constants
###########################################################################################################

# text to be searched in files
search_pattern_tim = (
    r'(.*[Rr]eplace.*\n)?.*"git::https:\/\/github\.com\/terraform-ibm-modules\/'
)
search_pattern_ge = (
    r'(.*[Rr]eplace.*\n)?.*"git::https:\/\/github\.ibm\.com\/GoldenEye\/'
)
# variable to store the text that we want to replace in files
replace_text = '  source  = "'
files_to_be_searched = ["**/*.tf", "**/*.md"]
# terraform registry APIs
get_by_name = "https://registry.terraform.io/v1/modules/terraform-ibm-modules/"
get_by_query_string = (
    "https://registry.terraform.io/v1/modules/search?q=terraform-ibm-modules%20"
)

###########################################################################################################
# Core Logic
###########################################################################################################


# get the current working repo
def get_repo():
    repo = git.Repo(os.getcwd())
    repo_name = repo.remotes.origin.url
    return repo_name


# get source information from terraform registry
def get_response(repo_name):
    try:
        # search using namespace/name/provider
        r = requests.get(get_by_name + "cos1" + "/ibm")
        if r.status_code == 200:
            return r.json()
        else:
            # search using query string
            r = requests.get(get_by_query_string + repo_name + "&limit=2&provider=ibm")
            return r.json()
    except requests.HTTPError:
        print(r.json())


# scans md, tf files and returns files to be updated
def get_files(extension, search_pattern, files, matched_lines):
    for file in glob.glob(extension, recursive=True):
        with open(file, "r") as reader:
            for line in reader:
                if re.search(search_pattern, line):
                    matched_lines.append(line)
                    files.append(file)
    return files, matched_lines


# extract id containing repo name and version
def extract_response(response):
    id = response["id"]
    return id


# replaces the source in the file content
def replace_source(file, search_pattern, replace_text, version_update, store):
    id, repo_name, version = extract_repo_details(store)
    with open(file, "r") as reader:
        file_data = reader.read()
        if version_update is True:
            version_replace_text = '\n  version = "' + version + '"'
        else:
            version_replace_text = '\n  version = "latest" # Replace "latest" with a release version to lock into a specific release'
        # replace source reference
        file_data = re.sub(
            search_pattern + ".*" + repo_name + ".*",
            replace_text + id.rsplit("/", 1)[0] + '"' + version_replace_text,
            file_data,
        )
    return file_data


# write replaced text and save file
def write_modified_content(file, data):
    with open(file, "w") as f:
        f.write(data)


# extract the repo name
def extract_repo_name(repo_name):
    if "terraform-ibm-" in repo_name:
        stripped_repo_name = repo_name.split("terraform-ibm-")
    else:
        stripped_repo_name = repo_name.split("-module")
    for rname in stripped_repo_name:
        if rname != "":
            return rname


# check if repo exists in the local dictionary
def check_repo_exists(repo_name, store):
    repo_check = False
    for storedata in store:
        for key, value in storedata.items():
            if re.search(repo_name, key):
                repo_check = True
    return repo_check


# extract id, repo anme and version from local store
def extract_repo_details(store):
    for storedata in store:
        for key, value in storedata.items():
            repo_name = key
            id = value.rsplit("/", 1)[0]
            version = value.rsplit("/", 1)[1]
    return id, repo_name, version


# get all referenced source information from terraform registry
def get_source_details(lines):
    store = []
    for line in lines:
        referenced_repo_name = re.sub(
            r"\?ref.*\n", "", (line.rsplit("/", 1)[1]).rsplit(".git", 1)[0]
        )

        stripped_repo_name = extract_repo_name(referenced_repo_name)
        # check if store has referenced repo details
        if check_repo_exists(stripped_repo_name, store) is False:
            response = get_response(stripped_repo_name)
            if "name" in response:
                id = extract_response(response)
                idobj = {stripped_repo_name: id}
                # append response to store
                store.append(idobj)

            elif "modules" in response:
                if len(response["modules"]) > 0:
                    id = extract_response(response["modules"][0])
                    idobj = {stripped_repo_name: id}
                    # append response to store
                    store.append(idobj)
    return store


###########################################################################################################
# Main
###########################################################################################################


def main():
    for current_file_extension in files_to_be_searched:
        if current_file_extension == "**/*.md":
            files = []
            store = []
            files, lines = get_files("**/*.md", search_pattern_tim, [], [])
            files, lines = get_files("**/*.md", search_pattern_ge, files, lines)
            store = get_source_details(lines)
            if len(files) > 0 and len(store) > 0:
                for file in files:
                    data = replace_source(
                        file, search_pattern_tim, replace_text, False, store
                    )
                    if data != "":
                        write_modified_content(file, data)
                    data = replace_source(
                        file, search_pattern_ge, replace_text, False, store
                    )
                    if data != "":
                        write_modified_content(file, data)
                print("Source references are updated in md files")
            else:
                print("No tf files found to update")

        if current_file_extension == "**/*.tf":
            files = []
            store = []
            files, lines = get_files("**/*.tf", search_pattern_tim, [], [])
            files, lines = get_files("**/*.tf", search_pattern_ge, files, lines)
            store = get_source_details(lines)
            if len(files) > 0 and len(store) > 0:
                for file in files:
                    data = replace_source(
                        file, search_pattern_tim, replace_text, True, store
                    )
                    if data != "":
                        write_modified_content(file, data)
                    data = replace_source(
                        file, search_pattern_ge, replace_text, True, store
                    )
                    if data != "":
                        write_modified_content(file, data)
                print("Source references are updated in tf files")
            else:
                print("No md files found to update")


main()
