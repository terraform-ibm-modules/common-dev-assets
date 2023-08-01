#!/usr/bin/python

import os
import sys
from subprocess import PIPE, Popen

import terraformDocsUtils

# temp file
markdown = "tf-docs.md"

for arg in sys.argv:
    if arg == sys.argv[0]:
        continue
    else:
        if terraformDocsUtils.is_hook_exists(
            "<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->", arg
        ):
            # get terraform docs content
            terraformDocsUtils.create_markdown("", markdown)
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

            if proc.returncode != 0:
                print(error)
                terraformDocsUtils.remove_markdown(markdown)
                sys.exit(proc.returncode)

            # add tf-docs.md content to main README
            os.system(
                f"terraform-docs --output-file {arg} -c common-dev-assets/module-assets/.terraform-docs-config.yaml ."
            )

            # remove temp file
            if os.path.exists(markdown):
                os.remove(markdown)
