import json
import os
import re
import sys
from subprocess import PIPE, Popen

validation_errors = []


# create a new temp file from catalogValidationValues.json.template and replace "$_strings_"
def create_temp_json(root, file):
    temp_file = os.path.join(root, "temp_" + file.replace(".template", ""))
    file_path = os.path.join(root, file)
    with open(file_path, "rt") as fin:
        with open(temp_file, "wt") as fout:
            for line in fin:
                # it can happens that the content of catalogValidationValues.json.template is in one row only (not pretty print format), in that case we must split the line according the delimiter
                multiple_lines = re.split("(,|{|})", line)
                for each_line in multiple_lines:
                    if "$" in each_line:
                        temp_value = (
                            '"temp_value",' if "," in each_line else '"temp_value"'
                        )
                        mytext = each_line[: each_line.rindex("$")] + temp_value
                        fout.write(mytext)
                    else:
                        fout.write(each_line)
    return temp_file


# check if a file is valid JSON
def is_json(myjson):
    with open(myjson) as json_file:
        try:
            json.load(json_file)
        except ValueError:
            return False
        return True


# create 'temp_tf_inputs.json' file using terraform-docs to get all tf inputs
def create_tf_input_json(root, output_file):
    # get tf inputs
    command = f'terraform-docs -c common-dev-assets/module-assets/.terraform-docs-config-validate-json-template.yaml --output-file {output_file} "{root}" '
    proc = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
    proc.communicate()

    # hard fail if error occurs
    if proc.returncode != 0:
        print(f'Error creating "{root}" tf inputs file: {proc.communicate()[1]}.')
        sys.exit(proc.returncode)


# get terraform inputs from '*.tf'
def get_tf_inputs_with_tf_docs(root):
    tf_inputs_name = []
    temp_tf_inputs_json_file = "temp_tf_inputs.json"
    create_tf_input_json(root, temp_tf_inputs_json_file)

    with open(os.path.join(root, temp_tf_inputs_json_file)) as json_data:
        data = json.load(json_data)
        for tf_input in data["inputs"]:
            tf_inputs_name.append(tf_input["name"])

    # remove temp temp_tf_inputs.json file
    os.remove(os.path.join(root, temp_tf_inputs_json_file))
    return tf_inputs_name


# get terraform inputs from 'stack_definition.json' file
def get_tf_inputs_from_stack_definition(root, stack_definition_json_file):
    tf_inputs_name = []

    with open(os.path.join(root, stack_definition_json_file)) as json_data:
        data = json.load(json_data)
        for tf_input in data["inputs"]:
            tf_inputs_name.append(tf_input["name"])
    return tf_inputs_name


# validate catalogValidationValues.json.template keys
def validate_inputs(root, temp_catalog_template_file, original_catalog_template_file):
    # terraform inputs
    tf_inputs_name = []
    stack_definition_json_file = "stack_definition.json"
    is_stack = False

    # if '*.tf' file exists then get the terraform inputs using terraform-docs
    if any(File.endswith(".tf") for File in os.listdir(root)):
        tf_inputs_name = get_tf_inputs_with_tf_docs(root)
    # if '*.tf' file does not exist then get the terraform inputs from 'stack_definition.json' file (Stack case)
    elif any(File == stack_definition_json_file for File in os.listdir(root)):
        is_stack = True
        tf_inputs_name = get_tf_inputs_from_stack_definition(
            root, stack_definition_json_file
        )
    # if '*.tf' and 'stack_definition.json' files do not exist then add validation error
    else:
        validation_errors.append(
            f"'catalogValidationValues.json.template' shouldn't exists in '{root}' if '*.tf' or 'stack_definition.json' files are not in this directory."
        )

    # validate only if terraform inputs exist
    if tf_inputs_name:
        # get catalog template keys
        catalog_template_keys = []
        with open(temp_catalog_template_file) as json_catalog_template_data:
            data = json.load(json_catalog_template_data)
            catalog_template_keys = data.keys()

        # check if catalog_template key is part of terraform input variables of the same directory
        for catalog_template_key in catalog_template_keys:

            # if 'ibmcloud_api_key' is defined in stack's json template then do not validate it
            if is_stack is True and catalog_template_key == "ibmcloud_api_key":
                continue

            if catalog_template_key not in tf_inputs_name:
                validation_errors.append(
                    f"'{catalog_template_key}' defined in '{original_catalog_template_file}' is not a valid input variable."
                )


def main():
    # find all 'catalogValidationValues.json.template' files in 'solutions' folder
    for root, dirs, files in os.walk("."):
        for file in files:
            if file.endswith("catalogValidationValues.json.template"):
                if ".terraform" not in os.path.join(root, file):

                    # create a new temp catalogValidationValues.json.template file
                    original_catalog_file = os.path.join(root, file)
                    temp_catalog_file = create_temp_json(root, file)

                    # if catalogValidationValues.json.template is not valid JSON format then save the error
                    if not is_json(temp_catalog_file):
                        validation_errors.append(
                            original_catalog_file + " is not valid JSON format."
                        )
                    else:
                        validate_inputs(root, temp_catalog_file, original_catalog_file)

                    os.remove(
                        temp_catalog_file
                    )  # remove temp catalogValidationValues.json.template file

    # if any validation error occurs then print the error and fail the hook
    if validation_errors:
        for error in validation_errors:
            print(error)
        sys.exit(1)


if __name__ == "__main__":
    main()
