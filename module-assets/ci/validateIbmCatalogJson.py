import json
import os
import sys
from subprocess import PIPE, Popen

IBM_CATALOG_FILE = "ibm_catalog.json"
DA_FOLDER = "solutions"
ERRORS = []


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
# - input is not defined in ibm_catalog.json
# - ibm_catalog.json has extra (not needed) inputs
# - any duplicates exists in ibm_catalog.json
def check_errors(
    inputs_not_in_catalog, inputs_not_in_da, duplicates, working_directory
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

    if error:
        errors.insert(0, f"\nFor '{working_directory}':")
        for val in errors:
            ERRORS.append(val)


# get inputs for solution defined in ibm_catalog.json file
def check_ibm_catalog_file():
    catalog_inputs = []

    # read ibm_catalog.json content
    with open(IBM_CATALOG_FILE) as f:
        ibm_catalog = json.load(f)

    # loop through flavors and check inputs for each solution defined in working_directory
    if ibm_catalog and "products" in ibm_catalog and ibm_catalog["products"]:
        for product in ibm_catalog["products"]:
            if "flavors" in product and product["flavors"]:
                for flavor in product["flavors"]:
                    if "working_directory" in flavor and flavor["working_directory"]:
                        working_directory = flavor["working_directory"]

                        da_path = f"{os.getcwd()}/{working_directory}"

                        # check if DA defined in working_directory exists
                        if not os.path.isdir(da_path):
                            ERRORS.append(
                                f"\nFor '{working_directory}':\n- solution does not exists"
                            )
                            continue

                        # get input variable names of a solution
                        da_inputs = get_inputs(da_path)

                        # get inputs defined in ibm_catalog.json for working_directory
                        if "configuration" in flavor and flavor["configuration"]:
                            catalog_inputs = [x["key"] for x in flavor["configuration"]]

                        # compare input variables defined in a solution with the one's defined in ibm_catalog.json
                        inputs_not_in_catalog = check_inputs_missing(
                            da_inputs, catalog_inputs
                        )
                        inputs_not_in_da = check_inputs_extra(da_inputs, catalog_inputs)
                        duplicates = find_duplicates(catalog_inputs)

                        check_errors(
                            inputs_not_in_catalog,
                            inputs_not_in_da,
                            duplicates,
                            working_directory,
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
    inputs = [x["name"] for x in json_object["inputs"]]
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


if __name__ == "__main__":
    if os.path.isfile(IBM_CATALOG_FILE):
        check_ibm_catalog_file()
        if len(ERRORS) > 0:
            for error in ERRORS:
                print(error)
            sys.exit(1)
