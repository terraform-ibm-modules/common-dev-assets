#!/usr/bin/python

import os
import sys
from subprocess import PIPE, Popen

import terraformDocsUtils

for arg in sys.argv:
    if arg == sys.argv[0]:
        continue
    else:
        # only run terradocs on readme files with the metadata tags
        if terraformDocsUtils.is_hook_exists(
            "<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->", arg
        ):
            # temp file
            markdown = "tf-docs.md"

            # change dir
            cwd = os.getcwd()
            if arg == "README.md":
                dirname = cwd
            else:
                dirname = os.path.dirname(arg)
            os.chdir(dirname)

            # get terraform docs content
            get_tf_docs_content_command = (
                "terraform-docs --hide providers markdown table ."
            )
            proc = Popen(
                get_tf_docs_content_command, stdout=PIPE, stderr=PIPE, shell=True
            )
            output, error = proc.communicate()

            # store tf docs content into temp file and change headings from lvl 2 to lvl 3
            with open(markdown, "w") as writer:
                writer.write(output.decode("utf-8").strip().replace("##", "###"))

            # hard fail if error
            if proc.returncode != 0:
                print(error)
                terraformDocsUtils.remove_markdown(markdown)
                os.chdir(cwd)
                sys.exit(proc.returncode)

            # add tf-docs.md content to README.md
            os.system(
                f"terraform-docs -c {cwd}/common-dev-assets/module-assets/.terraform-docs-config.yaml ."
            )

            # remove temp file
            terraformDocsUtils.remove_markdown(markdown)
            os.chdir(cwd)
