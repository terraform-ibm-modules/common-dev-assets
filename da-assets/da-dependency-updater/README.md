# DA Dependency Update Script

This Python script updates the DA dependency versions in an ibm_catalog.json JSON file. It retrieves the latest version for each dependency using the IBM Cloud Catalog Management API.

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

1. Set the `IBM_CLOUD_API_KEY` environment variable with your IBM Cloud API Key used to query Catalog. Alternatively, you can pass the API key as a command-line argument using the `--api-key` or `-k` flag.

## Usage

Ensure that you have activated the Python virtual environment before running the script.

```bash
source venv/bin/activate
```

Run the script using the following command:

```bash
python3 update_da_dependencies.py --catalog_json  path/to/ibm_catalog.json} --apikey your_api_key
```


- `--catalog_json` or `-s`: Path to the IBM catalog definition JSON file (required).
- `--apikey` or `-k`: IBM Cloud API Key. If not provided, the script will use the `IBM_CLOUD_API_KEY` environment variable (optional).
- `--debug`: Set the log level to DEBUG for more detailed output (optional).
- `--dry-run` or `-d`: Perform a dry run without updating the ibm_catalog.json file (optional).
- `--help`: Display the help message and exit (optional).

Example:

```bash
python3 update_da_dependencies.py --catalog_json path/to/ibm_catalog.json --apikey your_api_key --dry-run --debug
```


## How It Works

1. The script reads the `ibm_catalog` JSON file and iterates through each dependent DA.
3. It retrieves the versions of the dependency filtering by flavor.
4. The script selects the latest version retrieved from catalog using the `newest_version` function.
5. If the latest version differs from the current version, the script updates the DAs dependency's version in the IBM catalog definition.
6. Finally, if any updates were made, the script writes the updated DA definition back to the JSON file.

## Logging

The script uses the `logging` module for logging messages. By default, the log level is set to `INFO`. You can enable more detailed logging by setting the log level to `DEBUG` using the `--debug` flag.
