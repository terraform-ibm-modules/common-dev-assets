import json
import os
import sys
from pathlib import Path
from subprocess import PIPE, Popen

IBM_CATALOG_FILE = "ibm_catalog.json"
DA_FOLDER = "solutions"


# get inputs for solution defined in ibm_catalog.json file
def check_ibm_catalog_file(da_name):
    inputs = []
    with open(IBM_CATALOG_FILE) as f:
        ibm_catalog = json.load(f)
    if ibm_catalog and ibm_catalog["products"]:
        for product in ibm_catalog["products"]:
            if product["flavors"]:
                for flavor in product["flavors"]:
                    if (
                        flavor["working_directory"]
                        and flavor["working_directory"] == f"{DA_FOLDER}/{da_name}"
                        and flavor["configuration"]
                    ):
                        inputs = [x["key"] for x in flavor["configuration"]]
    return inputs


# get inputs for solution defined in solutions folder
def get_inputs(da_name):
    inputs = []
    da_path = f"{os.getcwd()}/{DA_FOLDER}/{da_name}"
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


# check solution inputs
def check_da(da_names):
    for da_name in da_names:
        da_inputs = get_inputs(da_name)
        catalog_inputs = check_ibm_catalog_file(da_name)
        inputs_not_in_catalog = check_inputs_missing(da_inputs, catalog_inputs)
        inputs_not_in_da = check_inputs_extra(da_inputs, catalog_inputs)

        if len(inputs_not_in_catalog) > 0 or len(inputs_not_in_da):
            print(
                f"For solution '{da_name}' the following inputs should be defined in ibm_catalog.json: {inputs_not_in_catalog}"
            )
            print(
                f"For solution '{da_name}' the following inputs should not be defined in ibm_catalog.json: {inputs_not_in_da}"
            )
            sys.exit(1)


# get solutions
def get_da_names():
    da_names = ""
    path = Path(DA_FOLDER)
    da_names = os.listdir(path)
    return da_names


if __name__ == "__main__":

    if os.path.isdir(DA_FOLDER) and os.path.isfile(IBM_CATALOG_FILE):
        da_names = get_da_names()
        check_da(da_names)
