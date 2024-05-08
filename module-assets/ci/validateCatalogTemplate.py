import json
import os
import sys
from subprocess import PIPE, Popen

validation_errors = []


# create a new temp file from catalogValidationValues.json.template and replace "$_strings_"
def create_temp_catalog(root, file):
    temp_file = os.path.join(root, "temp_" + file.replace(".template", ""))
    file_path = os.path.join(root, file)
    with open(file_path, "rt") as fin:
        with open(temp_file, "wt") as fout:
            for line in fin:
                if "$" in line:
                    temp_value = '"temp_value",' if "," in line else '"temp_value"'
                    mytext = line[: line.rindex("$")] + temp_value
                    fout.write(mytext)
                else:
                    fout.write(line)
    return temp_file


# check if a file is valid JSON
def is_json(myjson):
    with open(myjson) as json_file:
        try:
            json.load(json_file)
        except ValueError:
            return False
        return True


# using terraform-docs to get all tf inputs
def create_tf_input_json(root, output_file):
    # get tf inputs
    command = f'terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-validate-catalog.yaml --output-file {output_file} "{root}" '
    proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
    proc.communicate()

    # hard fail if error occurs
    if proc.returncode != 0:
        print(f'Error creating "{root}" tf inputs file: {proc.communicate()[1]}.')
        sys.exit(proc.returncode)


# validate catalog keys
def validate_inputs(root, temp_catalog_file):
    temp_tf_inputs_json_file = "temp_tf_inputs.json"
    create_tf_input_json(root, temp_tf_inputs_json_file)

    catalog_keys = []
    with open(temp_catalog_file) as json_catalog_data:
        data = json.load(json_catalog_data)
        catalog_keys = data.keys()

    tf_inputs_name = []
    with open(os.path.join(root, temp_tf_inputs_json_file)) as json_data:
        data = json.load(json_data)
        for tf_input in data["inputs"]:
            tf_inputs_name.append(tf_input["name"])

    # check if catalog key is part of terraform input variables of the same directory
    for catalog_key in catalog_keys:
        if catalog_key not in tf_inputs_name:
            validation_errors.append(
                f"Catalog key '{catalog_key}' in '{temp_catalog_file}' is not part of \"{root}\" tf inputs."
            )

    os.remove(
        os.path.join(root, temp_tf_inputs_json_file)
    )  # remove temp temp_tf_inputs.json file


# find all 'catalogValidationValues.json.template' files in 'solutions' folder
for root, dirs, files in os.walk("solutions"):
    for file in files:
        if file.endswith("catalogValidationValues.json.template"):
            if ".terraform" not in os.path.join(root, file):

                # create a new temp catalogValidationValues.json.template file
                temp_catalog_file = create_temp_catalog(root, file)

                # if catalogValidationValues.json.template is not valid JSON file then save the error
                if not is_json(temp_catalog_file):
                    validation_errors.append(
                        os.path.join(root, file) + " is not valid JSON file."
                    )
                else:
                    validate_inputs(root, temp_catalog_file)

                os.remove(
                    temp_catalog_file
                )  # remove temp catalogValidationValues.json.template file

# if any validation error occurs then print the error and fail the hook
if validation_errors:
    for error in validation_errors:
        print(error)
    sys.exit(1)
