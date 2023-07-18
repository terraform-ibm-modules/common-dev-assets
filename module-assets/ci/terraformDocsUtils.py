import os


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
