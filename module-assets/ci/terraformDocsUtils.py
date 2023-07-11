import os
from pathlib import Path


# create temp markdown which content is added to main README
def create_markdown(newlines, markdown):
    with open(markdown, "w") as writer:
        if len(newlines) > 0:
            for line in newlines:
                writer.writelines((str(line), "\n"))


#  remove temp markdown
def remove_markdown(markdown):
    if os.path.exists(markdown):
        os.remove(markdown)


# check if folder contains any tf file
def has_tf_files(path):
    if any(File.endswith(".tf") for File in os.listdir(path)):
        return True
    else:
        return False


# check if pre-commmit hook tag exists on main README.md
def is_hook_exists(hook_tag):
    exists = False
    with open("README.md", "r") as reader:
        lines = reader.readlines()
        for line in lines:
            if hook_tag in line:
                exists = True
    return exists


# Return title (first line) of README file
def get_readme_title(readme_file):
    with open(readme_file, "r") as reader:
        line = reader.readline()
        return line


# get first line of all README files inside specific path
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
