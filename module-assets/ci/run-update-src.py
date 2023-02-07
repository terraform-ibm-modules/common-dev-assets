# #!/usr/bin/env python3

# # This script is to update module source references to hashicorp registry

import git
import os
import urllib.request
import glob
import re
import json

# text to be searched in files
search_pattern = r'(.*[Rr]eplace.*\n)?.*"git::https:\/\/github\.com\/terraform-ibm-modules\/'
# variable to store the text that we want to replace in markdown files
replace_text = '  source  = "'
files_to_be_searched = ["**/*.tf", "**/*.md"]

def get_repo():
    repo = git.Repo(os.getcwd())
    repo_name = repo.remotes.origin.url
    return repo_name

def get_registry(repo_name):
    stripped_repo_name = repo_name.split("terraform-ibm-")
    for rname in stripped_repo_name:
        if rname != '':
            r = urllib.request.urlopen('https://registry.terraform.io/v1/modules/search?q=terraform-ibm-modules%20' +rname+ '&limit=2&provider=ibm')
            rescode = r.getcode()
            if rescode == 200:
                json_response = r.read().decode('utf-8') 
                return json.loads(json_response)
            else: return "Error retrieving response"

# scans md, tf files and returns files to be updated
def get_files(extension, search_pattern):
    files= []
    matched_lines = []
    # search for files
    for file in glob.glob(extension, recursive=True):
        with open(file, "r") as reader:
            for line in reader:
                if re.search(search_pattern, line):
                    matched_lines.append(line)
                    files.append(file)
    return files, matched_lines

def search_file(file_path, search_string):
    with open(file_path, 'r') as file:
        for line in file:
            if re.search(search_string, line):
                return line

def extract_response(response):
    item = response["modules"][0]
    id = item["id"]
    version= item["version"]
    return id,version

# replaces the source in the file content
def replace_src(file, search_pattern,repo_name, replace_text,versionUpdate, id, version):
    with open(file, "r") as reader:
        file_data = reader.read()
        if versionUpdate==True:
            version_replace_text = '\n  version = "' + version + '"'
        else: version_replace_text = '\n  version = "latest" # Replace "latest" with a release version to lock into a specific release'
        # replace source reference
        file_data = re.sub(search_pattern + repo_name + ".*", replace_text + id.rsplit('/', 1)[0] + '"' + version_replace_text, file_data)
    return file_data

# write replaced text to file
def write_modified_content(file, data):
    # write and save the file
    with open(file, "w") as f:
        f.write(data)


def main():
    files = []
    for current_file_extension in files_to_be_searched:
        if current_file_extension == "**/*.md":
            files, lines = get_files("**/*.md", search_pattern)
            if len(files) > 0:
                repo_name = get_repo()
                trimmed_repo_name = (repo_name.rsplit('/', 1)[1]).rsplit('.git', 1)[0]
                response = get_registry(trimmed_repo_name)
                if len(response["modules"]) > 0:
                    id, version = extract_response(response)
                    for file in files:
                        data = replace_src(file, search_pattern, trimmed_repo_name, replace_text,False, id, version) 
                        if data != '':
                            write_modified_content(file, data)   
                    print("Source references are updated in md files")
                        
        if current_file_extension == "**/*.tf":
            files = []
            files, matched_lines = get_files("**/*.tf", search_pattern)
            if len(files) > 0:
                for line in matched_lines:
                    referenced_repo_name = re.sub('\?ref.*\n', '' , (line.rsplit('/', 1)[1]).rsplit('.git', 1)[0])
                    response = get_registry(referenced_repo_name)
                    if len(response["modules"])  > 0:
                        id, version = extract_response(response)
                        for file in files:
                            data = replace_src(file, search_pattern, referenced_repo_name, replace_text,True, id, version) 
                            if data != '':
                                write_modified_content(file, data)  
                        print("Source references are updated in tf files")

print("Nothing to update")
    
main()
