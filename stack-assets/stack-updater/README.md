# Stack Definition Update Script

This Python script updates the version locators of stack members in a stack definition JSON file. It retrieves the latest valid version for each member using the IBM Cloud Catalog Management API.

## Prerequisites

- Python 3.x
- IBM Cloud API Key with access to all the tiles in the IBM Cloud Catalog
- Required Python packages listed in `requirements.txt`

## Installation

1. Clone the repository.

2. Create a Python virtual environment in the repository directory.

3. Install the required Python packages using pip and the `requirements.txt` file:

```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install -r requirements.txt
```

## Configuration

1. Set the `IBM_CLOUD_API_KEY` environment variable with your IBM Cloud API Key. The API key must have access to all the tiles in the IBM Cloud Catalog to update the stack members. Alternatively, you can pass the API key as a command-line argument using the `--api-key` or `-k` flag.

2. Ensure that the stack definition JSON file you want to update is accessible and properly formatted.

## Usage

Ensure that you have activated the Python virtual environment before running the script.

```bash
source venv/bin/activate
```

Run the script using the following command:

```bash
python3 update_stack_definition.py --stack-definition <path_to_stack_definition_file>
```


- `--stack` or `-s`: Path to the stack definition JSON file (required).
- `--api-key` or `-k`: IBM Cloud API Key. If not provided, the script will use the `IBM_CLOUD_API_KEY` environment variable (optional).
- `--debug`: Set the log level to DEBUG for more detailed output (optional).
- `--dry-run` or `-d`: Perform a dry run without updating the stack definition file (optional).
- `--help`: Display the help message and exit (optional).

Example:

```bash
python3 update_stack_definition.py --stack path/to/stack_definition.json --api-key your_api_key --dry-run --debug
```


## How It Works

1. The script reads the stack definition JSON file and iterates through each stack member.
2. For each member, it retrieves the current version details using the `get_version` function and the member's version locator.
3. It then retrieves the available version updates for the member using the `get_version_updates` function, filtering by the catalog ID, offering ID, kind, and flavor.
4. The script selects the latest valid version from the retrieved updates using the `get_latest_valid_version` function.
5. If the latest valid version locator differs from the current version locator, the script updates the member's version locator in the stack definition.
6. Finally, if any updates were made, the script writes the updated stack definition back to the JSON file.

## Logging

The script uses the `logging` module for logging messages. By default, the log level is set to `INFO`. You can enable more detailed logging by setting the log level to `DEBUG` using the `--debug` flag.
