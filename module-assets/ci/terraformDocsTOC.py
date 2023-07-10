#!/usr/bin/python

import os
import terraformDocsUtils
from pathlib import Path
from typing import Tuple, List


# Check if a line is a heading
def get_title(line: str, code_block: bool, comment_block: bool) -> Tuple[int, str, bool, bool]:
    level = 0
    for c in line:
        # set a flag to know if the lines are inside code block
        if '```' in line:
            code_block = not code_block
            break
        # one line comment, skip it
        elif '<!--' in line and '-->' in line:
            break
        # comment block begin -> set flag to true
        elif '<!--' in line:
            comment_block = True
            break
        # comment block end -> set flag to false
        elif '-->' in line:
            comment_block = False
            break
        # do not check lines if they are inside comment or code block
        elif code_block is False and comment_block is False:
            if c == '#':
                level += 1
            else:
                break
    title = line[level + 1:-1]

    return (level, title, code_block, comment_block)


# create table of contents
def create_main_toc(buffer, path):
    with open(path, 'r') as f:
        code_block = False
        comment_block = False
        for line in f.readlines():
            level, title, code_block, comment_block = get_title(line, code_block, comment_block)
            code_block = code_block
            comment_block = comment_block
            # level 1 is main heading, add it to TOC
            if level == 1:
                buffer.append('    ' * (level) + f"* [{title}](#{title.replace(' ', '-' )})")
            # examples, developing and contributing must be added to TOC at level 0
            if "examples" == title.lower() or "developing" == title.lower() or "contributing" == title.lower():
                level = 0
                buffer.append('    ' * (level) + f"* [{title}](#{title.replace(' ', '-' )})")
    return buffer


def get_module_headings():
    readme_headings: List[str] = []
    if os.path.isdir("modules"):
        for readme_file_path in Path("modules").rglob("README.md"):
            path = str(readme_file_path)
            # ignore README file if it has dot(.) in a path or the parent path does not contain any tf file
            if not ("/.") in path and terraformDocsUtils.has_tf_files(readme_file_path.parent):
                readme_title = terraformDocsUtils.get_readme_title(path)
                if readme_title:
                    data = '    * [{}](./{})'.format(readme_title.replace("\n", "").replace("# ", ""), path)
                    readme_headings.append(data)
    return sorted(readme_headings)


def main():
    if terraformDocsUtils.is_hook_exists("<!-- BEGIN TOC HOOK -->"):
        toc: List[str] = []
        toc.append("* [Terraform modules](#Terraform-modules)")
        path: str = "./README.md"
        toc_markdown = "TOC.md"

        # create TOC from main readme
        toc = create_main_toc(toc, path)

        # get module headings
        buffer2 = get_module_headings()

        # add submodule headings to main TOC after main module heading (second element in a list). Start adding after index 1.
        for index, readme_file_path in enumerate(buffer2):
            toc.insert(index + 2, readme_file_path)

        # create markdown
        terraformDocsUtils.create_markdown(toc, toc_markdown)

        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-toc.yaml ."
        )
        terraformDocsUtils.remove_markdown(toc_markdown)


main()
