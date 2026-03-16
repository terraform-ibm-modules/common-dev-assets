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
                anchor = title.replace(" ", "-").lower()
                heading = f'  <li><a href="#{anchor}">{title}</a></li>'
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


def generate_deploy_button_html(deploy_url, inline=False):

    badge_url = "https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe"

    if inline:
        return (
            f'<a href="{deploy_url}">'
            f'<img src="{badge_url}" alt="Deploy with IBM Cloud Schematics" '
            f'style="height: 16px; vertical-align: text-bottom; margin-left: 5px;">'
            f"</a>"
        )
    else:
        return (
            f"<p>\n"
            f'  <a href="{deploy_url}">\n'
            f'    <img src="{badge_url}" alt="Deploy with IBM Cloud Schematics">\n'
            f"  </a><br>\n"
            f"  ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.\n"
            f"</p>"
        )


def generate_deploy_url(repo_url, module_name, example_name):
    workspace_name = f"{module_name}-{example_name}-example"
    return (
        f"https://cloud.ibm.com/schematics/workspaces/create?"
        f"workspace_name={workspace_name}&"
        f"repository={repo_url}/tree/main/examples/{example_name}"
    )


def generate_deploy_tip():
    return "ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab."


def add_deploy_button_to_example_readme(example_path, repo_url, module_name):
    readme_path = os.path.join(example_path, "README.md")
    if not os.path.exists(readme_path):
        return

    # Read existing README content
    with open(readme_path) as f:
        content = f.read()

    example_name = os.path.basename(example_path)
    deploy_url = generate_deploy_url(repo_url, module_name, example_name)

    hook_begin = "<!-- BEGIN SCHEMATICS DEPLOY HOOK -->"
    hook_end = "<!-- END SCHEMATICS DEPLOY HOOK -->"
    tip_hook_begin = "<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->"
    tip_hook_end = "<!-- END SCHEMATICS DEPLOY TIP HOOK -->"

    # Generate HTML button with tip included
    deploy_button_html = generate_deploy_button_html(deploy_url, inline=False)

    if hook_begin in content and hook_end in content:
        # Replace content between hooks with HTML version
        pattern = r"<!-- BEGIN SCHEMATICS DEPLOY HOOK -->.*?<!-- END SCHEMATICS DEPLOY HOOK -->"
        new_content = f"{hook_begin}\n{deploy_button_html}\n{hook_end}"
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
        deploy_section = f"\n{hook_begin}\n{deploy_button_html}\n{hook_end}\n"

        # Insert after the first heading
        lines.insert(insert_position, deploy_section)
        content = "\n".join(lines)

    # Remove old tip hook if it exists
    if tip_hook_begin in content and tip_hook_end in content:
        pattern = r"<!-- BEGIN SCHEMATICS DEPLOY TIP HOOK -->.*?<!-- END SCHEMATICS DEPLOY TIP HOOK -->"
        content = re.sub(pattern, "", content, flags=re.DOTALL)
        content = content.replace("\n\n\n", "\n\n")  # Clean up extra newlines

    content = content.rstrip() + "\n"

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
                if "modules" == folder_name.lower():
                    module_name_display = re.sub(
                        regex_pattern,
                        "",
                        path.replace("modules/", ""),
                        flags=re.IGNORECASE,
                    )
                    module_path = re.sub(regex_pattern, "", path, flags=re.IGNORECASE)
                    data = f'      <li><a href="./{module_path}">{module_name_display}</a></li>'
                elif folder_name == "Deployable Architectures":
                    # for deployable architectures bullet point name is title in solution's README
                    readme_title = terraformDocsUtils.get_readme_title(path)
                    if readme_title:
                        title = readme_title.strip().replace("\n", "").replace("# ", "")
                        solution_path = re.sub(
                            regex_pattern, "", path, flags=re.IGNORECASE
                        )
                        data = f'      <li><a href="./{solution_path}">{title}</a></li>'
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
                        deploy_button_html = generate_deploy_button_html(
                            deploy_url, inline=True
                        )

                        data = (
                            f"      <li>\n"
                            f'        <a href="./{example_path}">{title}</a>\n'
                            f"        {deploy_button_html}\n"
                            f"      </li>"
                        )

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
        # get headings
        readme_titles = get_headings(folder_name, repo_url, module_name)

        if folder_name == "Examples" and readme_titles:
            # Use HTML format for Examples section
            display_name = "Submodules" if folder_name == "Modules" else folder_name
            bullet_point = f'  <li><a href="./{directory_name}">{display_name}</a>'
            overview.append(bullet_point)
            bullet_point_index = overview.index(bullet_point)
            overview.insert(bullet_point_index + 1, "    <ul>")
            for index, readme_file_path in enumerate(readme_titles):
                overview.insert(index + bullet_point_index + 2, readme_file_path)

            overview.insert(bullet_point_index + 2 + len(readme_titles), "    </ul>")

            tip = "    " + generate_deploy_tip()
            overview.insert(bullet_point_index + 3 + len(readme_titles), tip)
            overview.insert(bullet_point_index + 4 + len(readme_titles), "  </li>")
        else:
            display_name = "Submodules" if folder_name == "Modules" else folder_name
            bullet_point = f'  <li><a href="./{directory_name}">{display_name}</a>'
            overview.append(bullet_point)
            bullet_point_index = overview.index(bullet_point)

            if readme_titles:
                overview.insert(bullet_point_index + 1, "    <ul>")

                for index, readme_file_path in enumerate(readme_titles):
                    overview.insert(index + bullet_point_index + 2, readme_file_path)

                overview.insert(
                    bullet_point_index + 2 + len(readme_titles), "    </ul>"
                )
                overview.insert(bullet_point_index + 3 + len(readme_titles), "  </li>")
            else:
                overview.insert(bullet_point_index + 1, "  </li>")


def main():
    repo_url, module_name = get_repo_info()

    if terraformDocsUtils.is_hook_exists("<!-- BEGIN OVERVIEW HOOK -->"):
        overview: list[str] = []
        overview_markdown = "overview.md"

        overview.append("<ul>")

        # add module name to an overview as a first element (HTML format)
        path = pathlib.PurePath(terraformDocsUtils.get_module_url())
        repo_name = path.name
        overview.append(f'  <li><a href="#{repo_name}">{repo_name}</a></li>')

        # add modules to "overview"
        add_to_overview(overview, "Modules", repo_url, module_name)

        # add compliance and security section if it exists in README
        if has_compliance_and_security_section():
            compliance_link = '  <li><a href="#compliance-and-security">Compliance and security</a></li>'
            overview.append(compliance_link)

        # add examples to "overview"
        add_to_overview(overview, "Examples", repo_url, module_name)

        # add deployable architectures (solutions) to "overview"
        add_to_overview(overview, "Deployable Architectures", repo_url, module_name)

        # add headings from README (known issues, contributing, or developing) to overview
        readme_headings = get_main_readme_headings()
        for heading in readme_headings:
            overview.append(heading)

        overview.append("</ul>")

        # create markdown
        terraformDocsUtils.create_markdown(overview, overview_markdown)

        # run terraform docs
        os.system(
            "terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-overview.yaml ."
        )

        terraformDocsUtils.remove_markdown(overview_markdown)

    update_all_example_readmes(repo_url, module_name)


main()
