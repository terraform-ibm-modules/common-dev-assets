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
    data = []
    with open("./README.md") as f:
        code_block = False
        comment_block = False
        for line in f.readlines():
            level, title, code_block, comment_block = get_title(
                line, code_block, comment_block
            )
            code_block = code_block
            comment_block = comment_block

            # known issues, developing and contributing must be added to overview at level 0
            if (
                "known issues" == title.lower()
                or "developing" == title.lower()
                or "contributing" == title.lower()
            ):
                level = 0
                heading = "    " * (level) + "* [{}](#{})".format(
                    title, title.replace(" ", "-").lower()
                )
                data.append(heading)
    return data


def has_compliance_and_security_section():
    """Check if README.md contains a 'Compliance and security' header"""
    try:
        with open("./README.md") as f:
            code_block = False
            comment_block = False
            for line in f.readlines():
                level, title, code_block, comment_block = get_title(
                    line, code_block, comment_block
                )
                code_block = code_block
                comment_block = comment_block

                # Check if this is a level 2 heading (##) with the title "Compliance and security"
                if level == 2 and title.lower() == "compliance and security":
                    return True
        return False
    except FileNotFoundError:
        return False


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
    return ":information_source: Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab"


def add_deploy_button_to_example_readme(example_path, repo_url, module_name):
    readme_path = os.path.join(example_path, "README.md")
    if not os.path.exists(readme_path):
        return

    # Read existing README content
    with open(readme_path) as f:
        content = f.read()

    example_name = os.path.basename(example_path)
    deploy_url = generate_deploy_url(repo_url, module_name, example_name)
    deploy_button = generate_deploy_button_html(deploy_url)

    hook_begin = "<!-- BEGIN SCHEMATICS DEPLOY HOOK -->"
    hook_end = "<!-- END SCHEMATICS DEPLOY HOOK -->"
    tip_hook_begin = "<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->"
    tip_hook_end = "<!-- END SCHEMATICS DEPLOY TIP HOOK -->"

    # Handle deploy button at the top
    if hook_begin in content and hook_end in content:
        # Replace content between hooks
        pattern = r"<!-- BEGIN SCHEMATICS DEPLOY HOOK -->.*?<!-- END SCHEMATICS DEPLOY HOOK -->"
        new_content = f"{hook_begin}\n{deploy_button}\n{hook_end}"
        content = re.sub(pattern, new_content, content, flags=re.DOTALL)
    else:
        # Find the position after the first heading (title)
        lines = content.split("\n")
        insert_position = 0

        # Find first heading (starts with #)
        for i, line in enumerate(lines):
            if line.strip().startswith("#"):
                insert_position = i + 1
                break

        # Create deploy section to insert at top
        deploy_section = f"\n{hook_begin}\n{deploy_button}\n{hook_end}\n"

        # Insert after the first heading
        lines.insert(insert_position, deploy_section)
        content = "\n".join(lines)

    # Handle deploy tip at the bottom
    deploy_tip = generate_deploy_tip()

    if tip_hook_begin in content and tip_hook_end in content:
        # Replace tip content between hooks
        pattern = r"<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->.*?<!-- END SCHEMATICS DEPLOY TIP HOOK -->"
        new_tip_content = f"{tip_hook_begin}\n{deploy_tip}\n{tip_hook_end}"
        content = re.sub(pattern, new_tip_content, content, flags=re.DOTALL)
    else:
        # Add tip section at the bottom
        tip_section = f"\n\n{tip_hook_begin}\n{deploy_tip}\n{tip_hook_end}\n"
        content = content.rstrip() + tip_section

    # Write back to README
    with open(readme_path, "w") as f:
        f.write(content)


def update_all_example_readmes(repo_url, module_name):
    if not os.path.isdir("examples"):
        return

    # Find all example directories
    for example_dir in os.listdir("examples"):
        example_path = os.path.join("examples", example_dir)

        # Skip if not a directory or starts with dot
        if not os.path.isdir(example_path) or example_dir.startswith("."):
            continue

        # Check if directory has terraform files
        if not terraformDocsUtils.has_tf_files(example_path):
            continue

        # Add deploy button to this example's README
        add_deploy_button_to_example_readme(example_path, repo_url, module_name)


def get_headings(folder_name, repo_url, module_name):
    readme_headings: list[str] = []

    # Map "Deployable Architectures" to "solutions" directory
    directory_name = (
        "solutions"
        if folder_name == "Deployable Architectures"
        else folder_name.lower()
    )

    if os.path.isdir(directory_name):
        for readme_file_path in Path(directory_name).rglob("*"):
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
                data = None
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
                elif folder_name == "Deployable Architectures":
                    # for deployable architectures bullet point name is title in solution's README
                    readme_title = terraformDocsUtils.get_readme_title(path)
                    if readme_title:
                        title = readme_title.strip().replace("\n", "").replace("# ", "")
                        solution_path = re.sub(
                            regex_pattern, "", path, flags=re.IGNORECASE
                        )
                        data = f'    * <a href="./{solution_path}">{title}</a>'
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

                if data is not None:
                    readme_headings.append(data)
    return sorted(readme_headings)


def add_to_overview(overview, folder_name, repo_url, module_name):
    # Map "Deployable Architectures" to "solutions" directory
    directory_name = (
        "solutions"
        if folder_name == "Deployable Architectures"
        else folder_name.lower()
    )

    if os.path.isdir(directory_name):
        # add lvl 1 bullet point to an overview
        bullet_point = "* [{}](./{})".format(
            "Submodules" if folder_name == "Modules" else folder_name,
            directory_name,
        )
        overview.append(bullet_point)
        bullet_point_index = overview.index(bullet_point)

        if folder_name == "Examples":
            tip = generate_deploy_tip()
            overview.insert(bullet_point_index + 1, tip)

        # get headings
        readme_titles = get_headings(folder_name, repo_url, module_name)

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

        # add compliance and security section if it exists in README
        if has_compliance_and_security_section():
            compliance_link = "* [Compliance and security](#compliance-and-security)"
            overview.append(compliance_link)

        # add examples to "overview"
        add_to_overview(overview, "Examples", repo_url, module_name)

        # add deployable architectures (solutions) to "overview"
        add_to_overview(overview, "Deployable Architectures", repo_url, module_name)

        # add headings from README (known issues, contributing, or developing) to overview
        readme_headings = get_main_readme_headings()
        for heading in readme_headings:
            overview.append(heading)

        # create markdown
        terraformDocsUtils.create_markdown(overview, overview_markdown)

        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-overview.yaml ."
        )

        terraformDocsUtils.remove_markdown(overview_markdown)

    update_all_example_readmes(repo_url, module_name)


main()
