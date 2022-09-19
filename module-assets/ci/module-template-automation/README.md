# Updating the module template readme file content
Most of the code for the readme file in the `module-template` or `terraform-ibm-module-template` repo is stored in [common-dev-assets](https://github.com/terraform-ibm-modules/common-dev-assets). To make changes to the readme file, update the files in this directory.

To modify the Markdown content, change the following files:
- To modify most content in the main readme file, update [.terraform-docs-config-template-module.yaml](.terraform-docs-config-template-module.yaml).
- To modify the contributing section of of the main readme file, update [.terraform-docs-config-template-module-contribution.yaml](.terraform-docs-config-template-module-contribution.yaml).
- To modify the readme file in the `tests` directory, update [.terraform-docs-config-template-module-tests.yaml](.terraform-docs-config-template-module-tests.yaml).

To update the default examples for the module template, update the code in the [examples](examples) directory in this rep.

To update the default tests, update the files in the [tests](tests) directory in this repo.

The [build_module_template](../../.pre-commit-config.yaml) pre-commit hook assembles the content for the module template repo. The hook runs the following actions:
- Copies the code, examples, and tests from this `common-dev-assets` repo to the `module-template` or `terraform-ibm-module-template` repo.
- Creates the readme files in the `module-template` or `terraform-ibm-module-template` repo.
