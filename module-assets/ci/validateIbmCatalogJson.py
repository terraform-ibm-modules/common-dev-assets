import json
import os
import pathlib
import re
import sys
from subprocess import PIPE, Popen

import terraformDocsUtils

IBM_CATALOG_FILE = "ibm_catalog.json"
DA_FOLDER = "solutions"
ERRORS = []


def is_strict_version(version_str):
    """
    Returns True if the version string is strictly pinned to a version like '1.10.0'.
    Rejects anything with comparison operators, ranges, or incomplete versions like '1.10'.
    """
    pattern = r"^\d+\.\d+\.\d+$"
    return re.match(pattern, version_str.strip()) is not None


# Find duplicates in array
def find_duplicates(array):
    n = len(array)
    duplicates = []
    # Create a set to store the unique elements
    unique = set()
    # Iterate through each element
    for i in range(n):
        # If the element is already present, then add it to duplicates
        # Else insert the element into the set
        if array[i] in unique:
            duplicates.append(array[i])
        else:
            unique.add(array[i])
    return duplicates


# Check for any error. If any error occurs, save it into global array and print it out at the end. We are checking if:
# - DA's input variable is not defined in ibm_catalog.json
# - ibm_catalog.json has extra (not needed) input variables
# - any duplicates exists in ibm_catalog.json
# - terraform_version is missing or not strictly defined
# - input variables of type list(object), map or any do not have HCL editor defined in ibm_catalog.json
# - short_description is missing
def check_errors(
    inputs_not_in_catalog,
    inputs_not_in_da,
    duplicates,
    working_directory,
    flavor_label,
    product_label,
    terraform_version_error,
    inputs_not_have_hcl_editor,
    terraform_short_description_error,
):
    error = False
    errors = []
    if len(inputs_not_in_catalog) > 0:
        errors.append(
            f"- the following inputs should be defined in ibm_catalog.json: {inputs_not_in_catalog}"
        )
        error = True
    if len(inputs_not_in_da) > 0:
        errors.append(
            f"- the following inputs should not be defined in ibm_catalog.json: {inputs_not_in_da}"
        )
        error = True
    if len(duplicates) > 0:
        errors.append(f"- ibm_catalog.json has duplicates: {duplicates}")
        error = True
    if terraform_version_error:
        errors.append(terraform_version_error)
        error = True
    if terraform_short_description_error:
        errors.append(terraform_short_description_error)
        error = True
    if len(inputs_not_have_hcl_editor) > 0:
        errors.append(
            f"- the following inputs should have HCL editor in ibm_catalog.json: {inputs_not_have_hcl_editor}"
            f"\n\n******* HCL editor syntax is: *******\n\n"
            f'"custom_config": {{\n'
            f'  "type": "code_editor",\n'
            f'  "grouping": "deployment",\n'
            f'  "original_grouping": "deployment",\n'
            f'  "config_constraints": {{\n'
            f'    "supportedLanguages": ["hcl"]\n'
            f"  }}\n"
            f"}}"
        )
        error = True
    if error:
        errors.insert(
            0,
            f"\nproduct_label: '{product_label}'\nflavor_label: '{flavor_label}'\nworking_directory: '{working_directory}':\n",
        )
        for val in errors:
            ERRORS.append(val)
    # if error is not thrown then check the JSON formatting
    else:
        # Read the JSON data
        with open(IBM_CATALOG_FILE, encoding="utf-8") as f:
            data = json.load(f)

        # Write JSON with pretty formatting (indentation)
        with open(IBM_CATALOG_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")  # Adds a single empty line at the end


# get inputs for solution defined in ibm_catalog.json file
def check_ibm_catalog_file():
    catalog_inputs = []
    catalog_inputs_names = []

    # read ibm_catalog.json content
    with open(IBM_CATALOG_FILE) as f:
        ibm_catalog = json.load(f)

    # get repo name
    path = pathlib.PurePath(terraformDocsUtils.get_module_url())
    repo_name = path.name

    # loop through flavors and check inputs for each solution defined in working_directory. Check only for "product_kind": "solution".
    if ibm_catalog and "products" in ibm_catalog and ibm_catalog["products"]:
        for product in ibm_catalog["products"]:
            if (
                "flavors" in product
                and product["flavors"]
                and "product_kind" in product
                and product["product_kind"]
                and product["product_kind"] == "solution"
            ):
                product_label = ""
                if "label" in product and product["label"]:
                    product_label = product["label"]

                for flavor in product["flavors"]:
                    terraform_version_error = None
                    terraform_short_description_error = None
                    flavor_label = ""
                    if "label" in flavor and flavor["label"]:
                        flavor_label = flavor["label"]

                    # if `working_directory` does not exist then default DA path to root
                    if "working_directory" in flavor and flavor["working_directory"]:
                        working_directory = flavor["working_directory"]
                    else:
                        working_directory = "./"

                    da_path = f"{os.getcwd()}/{working_directory}"

                    # if `working_directory` has a value of DA that does not exist, then add an error
                    if not os.path.isdir(da_path):
                        ERRORS.append(
                            f"\nproduct_label: '{product_label}'\nflavor_label: '{flavor_label}'\nworking_directory: '{working_directory}':\n\n- solution does not exists"
                        )
                        continue

                    # get input variable names of a solution
                    da_inputs = get_inputs(da_path)
                    da_inputs_names = [item["name"] for item in da_inputs]

                    # get inputs defined in ibm_catalog.json for working_directory
                    # inputs are needed for comparison with DA inputs
                    catalog_inputs = []
                    catalog_inputs_names = []
                    if "configuration" in flavor and flavor["configuration"]:
                        catalog_inputs = [
                            {
                                "name": x["key"],
                                # check whether custom_config is defined and is of type code_editor
                                "is_custom_config": (
                                    isinstance(x.get("custom_config"), dict)
                                    and x["custom_config"].get("type") == "code_editor"
                                ),
                                # include the whole custom_config for further checks
                                "custom_config": x.get("custom_config", {}),
                            }
                            for x in flavor["configuration"]
                            if not x.get("virtual", False)
                        ]
                        catalog_inputs_names = [item["name"] for item in catalog_inputs]

                    # compare input variables defined in a solution with the one's defined in ibm_catalog.json
                    inputs_not_in_catalog = check_inputs_missing(
                        da_inputs_names, catalog_inputs_names
                    )
                    inputs_not_in_da = check_inputs_extra(
                        da_inputs_names, catalog_inputs_names
                    )
                    duplicates = find_duplicates(catalog_inputs_names)

                    # check terraform_version if:
                    # - repo does not have 'stack-' in the name
                    if "stack-" not in repo_name:
                        # if terraform_version is not defined inside flavor then add an error
                        if not (
                            "terraform_version" in flavor
                            and flavor["terraform_version"]
                        ):
                            terraform_version_error = (
                                "- key 'terraform_version' is missing"
                            )
                        elif not is_strict_version(flavor["terraform_version"]):
                            version = flavor["terraform_version"]
                            terraform_version_error = f"- key 'terraform_version': '{version}' not the right format. Should be locked to a version and have MAJOR.MINOR.PATCH format."

                    # check whether the HCL editor is used for input variables of type list(object) or map
                    inputs_not_have_hcl_editor = check_hcl_editor(
                        da_inputs, catalog_inputs
                    )

                    # check whether short_description is defined
                    if not (
                        "short_description" in flavor and flavor["short_description"]
                    ):
                        terraform_short_description_error = (
                            "- key 'short_description' is missing"
                        )

                    check_errors(
                        inputs_not_in_catalog,
                        inputs_not_in_da,
                        duplicates,
                        working_directory,
                        flavor_label,
                        product_label,
                        terraform_version_error,
                        inputs_not_have_hcl_editor,
                        terraform_short_description_error,
                    )


# get input variables for a solution
def get_inputs(da_path):
    inputs = []
    command = f"terraform-docs --show inputs json {da_path}"
    proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
    output, error = proc.communicate()

    # hard fail if error occurs
    if proc.returncode != 0:
        print(f"Error getting inputs: {proc.communicate()[1]}")
        sys.exit(proc.returncode)

    json_object = json.loads(output)
    inputs = [{"name": x["name"], "type": x["type"]} for x in json_object["inputs"]]
    return inputs


# return inputs that are defined as solution (DA) input but are missing in ibm_catalog.json file
def check_inputs_missing(da_inputs, catalog_inputs):
    inputs_not_in_catalog = []
    for da_input in da_inputs:
        if da_input not in catalog_inputs:
            inputs_not_in_catalog.append(da_input)
    return inputs_not_in_catalog


# return inputs that are not defined as solution (DA) input but are added in ibm_catalog.json file
def check_inputs_extra(da_inputs, catalog_inputs):
    inputs_not_in_da = []
    for catalog_input in catalog_inputs:
        if catalog_input not in da_inputs:
            inputs_not_in_da.append(catalog_input)
    return inputs_not_in_da


# check whether the HCL editor is used for input variables of type list(object), map or any
def check_hcl_editor(da_inputs, catalog_inputs):
    inputs_not_have_hcl_editor = []
    for da_input in da_inputs:
        if (
            da_input["type"].startswith("list(object")
            or da_input["type"].startswith("map")
            or da_input["type"] == "any"
        ):
            catalog_input = next(
                (item for item in catalog_inputs if item["name"] == da_input["name"]),
                None,
            )
            # check whether HCL editor is used
            # if custom_config is not defined or is_custom_config is False or supportedLanguages does not have hcl then add to inputs_not_have_hcl_editor
            if catalog_input and catalog_input["is_custom_config"]:
                supported_languages = (
                    catalog_input["custom_config"]
                    .get("config_constraints", {})
                    .get("supportedLanguages", [])
                )
                if "hcl" not in supported_languages:
                    inputs_not_have_hcl_editor.append(da_input["name"])
            else:
                inputs_not_have_hcl_editor.append(da_input["name"])
    return inputs_not_have_hcl_editor


if __name__ == "__main__":
    if os.path.isfile(IBM_CATALOG_FILE):
        check_ibm_catalog_file()
        if len(ERRORS) > 0:
            for error in ERRORS:
                print(error)
            sys.exit(1)
