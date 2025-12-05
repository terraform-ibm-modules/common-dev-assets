#!/usr/bin/python

import os
import pathlib
import re
from pathlib import Path

import terraformDocGoMod
import terraformDocsUtils


# Check if a line is a heading
def get_title(
    line: str, code_block: bool, comment_block: bool
) -> tuple[int, str, bool, bool]:
    level = 0
    for c in line:
        # set a flag to know if the lines are inside code block
        if "```" in line:
            code_block = not code_block
            break
        # one line comment, skip it
        elif "<!--" in line and "-->" in line:
            break
        # comment block begin -> set flag to true
        elif "<!--" in line:
            comment_block = True
            break
        # comment block end -> set flag to false
        elif "-->" in line:
            comment_block = False
            break
        # do not check lines if they are inside comment or code block
        elif code_block is False and comment_block is False:
            if c == "#":
                level += 1
            else:
                break
    title = line[level + 1 : -1]

    return (level, title, code_block, comment_block)


# get main readme headings
def get_main_readme_headings():
    data = ""
    with open("./README.md") as f:
        code_block = False
        comment_block = False
        for line in f.readlines():
            level, title, code_block, comment_block = get_title(
                line, code_block, comment_block
            )
            code_block = code_block
            comment_block = comment_block

            # developing and contributing must be added to overview at level 0
            if "developing" == title.lower() or "contributing" == title.lower():
                level = 0
                data = "    " * (level) + "* [{}](#{})".format(
                    title, title.replace(" ", "-").lower()
                )
    return data


def get_repo_info():
    module_url = terraformDocsUtils.get_module_url()
    module_url = terraformDocGoMod.change_module_url(module_url)
    full_module_url = f"https://{module_url}"
    repo_name = pathlib.PurePath(module_url).name
    module_name = repo_name.replace("terraform-ibm-", "")

    return full_module_url, module_name


def generate_deploy_button_html(deploy_url, margin_left=0, height=16):
    margin_style = f" margin-left: {margin_left}px;" if margin_left > 0 else ""
    return (
        f'<a href="{deploy_url}">'
        f'<img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" '
        f'alt="Deploy with IBM Cloud Schematics" style="height: {height}px; vertical-align: text-bottom;{margin_style}">'
        f"</a>"
    )


def generate_deploy_url(repo_url, module_name, example_name):
    workspace_name = f"{module_name}-{example_name}-example"
    return (
        f"https://cloud.ibm.com/schematics/workspaces/create?"
        f"workspace_name={workspace_name}&"
        f"repository={repo_url}/tree/main/examples/{example_name}"
    )


def generate_deploy_tip():
    return (
        ":exclamation: Ctrl/Cmd+Click or right-click to open deploy button in a new tab"
    )


def add_deploy_button_to_example_readme(example_path, repo_url, module_name):
    """Add deploy button to example's README.md using hooks."""
    readme_path = os.path.join(example_path, "README.md")

    if not os.path.exists(readme_path):
        return

    with open(readme_path) as f:
        content = f.read()

    example_name = os.path.basename(example_path)
    deploy_url = generate_deploy_url(repo_url, module_name, example_name)
    deploy_button = generate_deploy_button_html(deploy_url)

    deploy_with_tip = f"{deploy_button}\n\n{generate_deploy_tip()}"

    hook_begin = "<!-- BEGIN SCHEMATICS DEPLOY HOOK -->"
    hook_end = "<!-- END SCHEMATICS DEPLOY HOOK -->"

    # Check if hooks exist
    if hook_begin in content and hook_end in content:
        pattern = r"<!-- BEGIN SCHEMATICS DEPLOY HOOK -->.*?<!-- END SCHEMATICS DEPLOY HOOK -->"
        new_content = f"{hook_begin}\n{deploy_with_tip}\n{hook_end}"
        content = re.sub(pattern, new_content, content, flags=re.DOTALL)
    else:
        deploy_section = f"\n\n{hook_begin}\n{deploy_with_tip}\n{hook_end}\n"
        content = content.rstrip() + deploy_section

    with open(readme_path, "w") as f:
        f.write(content)


def update_all_example_readmes(repo_url, module_name):
    if not os.path.isdir("examples"):
        return

    for example_dir in os.listdir("examples"):
        example_path = os.path.join("examples", example_dir)

        if not os.path.isdir(example_path) or example_dir.startswith("."):
            continue

        if not terraformDocsUtils.has_tf_files(example_path):
            continue

        add_deploy_button_to_example_readme(example_path, repo_url, module_name)


def get_headings(folder_name, repo_url, module_name):
    readme_headings: list[str] = []

    if os.path.isdir(folder_name.lower()):
        for readme_file_path in Path(folder_name.lower()).rglob("*"):
            path = str(readme_file_path)
            regex_pattern = r"README.md"

            # Compile the regex pattern and ignore case
            regex = re.compile(regex_pattern, re.IGNORECASE)

            if not regex.search(path):
                continue

            # ignore README file if it has dot(.) in a path or the parent path does not contain any tf file
            if ("/.") not in path and terraformDocsUtils.has_tf_files(
                readme_file_path.parent
            ):
                regex_pattern = r"/README.md"
                if "modules" == folder_name:
                    # for modules bullet point name is folder name
                    data = "    * [{}](./{})".format(
                        re.sub(
                            regex_pattern,
                            "",
                            path.replace("modules/", ""),
                            flags=re.IGNORECASE,
                        ),
                        re.sub(regex_pattern, "", path, flags=re.IGNORECASE),
                    )
                else:
                    # for examples bullet point name is title in example's README
                    readme_title = terraformDocsUtils.get_readme_title(path)
                    if readme_title:
                        title = readme_title.strip().replace("\n", "").replace("# ", "")
                        example_path = re.sub(
                            regex_pattern, "", path, flags=re.IGNORECASE
                        )
                        example_name = os.path.basename(example_path)

                        # Generate deploy URL and button
                        deploy_url = generate_deploy_url(
                            repo_url, module_name, example_name
                        )
                        deploy_button = generate_deploy_button_html(
                            deploy_url, margin_left=5
                        )

                        data = f'    * <a href="./{example_path}">{title}</a> {deploy_button}'

                readme_headings.append(data)
    return sorted(readme_headings)


def add_to_overview(overview, folder_name, repo_url, module_name):
    if os.path.isdir(folder_name.lower()):
        # add lvl 1 bullet point to an overview
        bullet_point = "* [{}](./{})".format(
            "Submodules" if folder_name == "Modules" else folder_name,
            folder_name.lower(),
        )
        overview.append(bullet_point)
        bullet_point_index = overview.index(bullet_point)

        if folder_name == "Examples":
            tip = generate_deploy_tip()
            overview.insert(bullet_point_index + 1, tip)

        # get headings
        readme_titles = get_headings(folder_name.lower(), repo_url, module_name)

        # Calculate offset: +2 for Examples (bullet + tip), +1 for others (just bullet)
        offset = 2 if folder_name == "Examples" else 1

        for index, readme_file_path in enumerate(readme_titles):
            # we need to add examples under Examples lvl 1 bullet point
            overview.insert(index + bullet_point_index + offset, readme_file_path)


def main():
    repo_url, module_name = get_repo_info()

    if terraformDocsUtils.is_hook_exists("<!-- BEGIN OVERVIEW HOOK -->"):
        overview: list[str] = []
        overview_markdown = "overview.md"

        # add module name to an overview as a first element
        path = pathlib.PurePath(terraformDocsUtils.get_module_url())
        repo_name = path.name
        overview.append(f"* [{repo_name}](#{repo_name})")

        # add modules to "overview"
        add_to_overview(overview, "Modules", repo_url, module_name)

        # add examples to "overview"
        add_to_overview(overview, "Examples", repo_url, module_name)

        # add last heading of README (contributing (external) or developing (internal)) to overview
        overview.append(get_main_readme_headings())

        # create markdown
        terraformDocsUtils.create_markdown(overview, overview_markdown)

        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-overview.yaml ."
        )

        terraformDocsUtils.remove_markdown(overview_markdown)

    update_all_example_readmes(repo_url, module_name)


main()
