## Updating template module content
Most of the code for `template module` is stored in [common-dev-assets](https://github.com/terraform-ibm-modules/common-dev-assets). Therefore, to make any code changes to `template module`, files inside this root must be updated.

If you would like to modify any markdown files then the code changes should be added to:
- [Modifying main README file](.terraform-docs-config-template-module.yaml)
- [Modifying contributing section of main README file](.terraform-docs-config-template-module-contribution.yaml)
- [Modifying tests README file](.terraform-docs-config-template-module-tests.yaml)

To update `examples` the code inside [examples](examples) should be changed.

To update `tests` the code inside [tests](tests) should be changed.

[build_module_template](../../.pre-commit-config.yaml) pre-commit hook is used to build up the content for this module. The hook executes the following actions:
- copies code, examples and tests from `common-dev-assets` into `template module` module
- creates markdown (README) files
