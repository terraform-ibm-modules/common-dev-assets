#!/usr/bin/python

import json
import os
import subprocess

badges_markdown = "badges_readme_markdown.md"


def get_template_values():
    return json.load(open("readme-template-values.json"))


def get_badge_template_content():
    content = []
    with open("ci/templates/badges_tmpl.md", "r") as file:
        template_values = get_template_values()
        for line in file:
            new_line = line
            for key in template_values:
                new_line = new_line.replace(key, template_values[key])
            # if placeholder has been changed then add a new line to a readme
            if "_ph" not in new_line:
                content.append(new_line)
    return content


def create_badges_markdown(newlines):
    with open(badges_markdown, "w") as writer:
        if len(newlines) > 0:
            for line in newlines:
                writer.writelines(line)


def run_terraform_docs():
    subprocess.run(
        [
            "terraform-docs",
            "-c",
            "common-dev-assets/module-assets/.terraform-docs-config-batch.yaml",
            ".",
        ],
        check=True,
    )


def remove_badges_markdown():
    if os.path.exists(badges_markdown):
        os.remove(badges_markdown)


def main():
    lines = get_badge_template_content()
    create_badges_markdown(lines)
    run_terraform_docs()
    remove_badges_markdown()


main()
