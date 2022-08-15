import os
from pathlib import Path


def is_terraform_repository():
    terraform_file_exists = False
    for file in Path("./").rglob("*.tf"):
        terraform_file_exists = True
        break
    return terraform_file_exists


if is_terraform_repository():
    os.system("terraform-config-inspect --json > module-metadata.json")
