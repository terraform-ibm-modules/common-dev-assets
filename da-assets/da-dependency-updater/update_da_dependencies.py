import argparse
import copy
import json
import logging
import os
import sys

from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
from ibm_platform_services.catalog_management_v1 import CatalogManagementV1

# Get the root logger
logger = logging.getLogger()


def newest_version(versions):
    # Parse and pad version numbers
    if not versions:
        raise ValueError("Failed to find newest version. The versions list is empty.")

    parsed = []
    max_parts = max(v.count(".") + 1 for v in versions)  # Find max parts in any version

    for v in versions:
        numbers = list(map(int, v[1:].split(".")))
        numbers += [0] * (max_parts - len(numbers))  # Pad with zeros
        parsed.append((tuple(numbers), v))

    return max(parsed)[1]


def intialize_parser():
    parser = argparse.ArgumentParser(description="Update DA Dependency Versions")
    parser.add_argument(
        "--catalog_json",
        "-s",
        type=str,
        action="store",
        dest="catalog_json",
        help="path of ibm_catalog.json file",
        required=True,
    )
    parser.add_argument(
        "--apikey",
        "-k",
        type=str,
        action="store",
        dest="apikey",
        help="IBM Cloud API Key, if not set, use IBM_CLOUD_API_KEY environment variable",
        required=False,
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        dest="debug",
        help="Enable debug logging",
        default=False,
    )
    parser.add_argument(
        "--dry-run",
        "-d",
        action="store_true",
        dest="dry_run",
        help="Dry run mode, do not update ibm_catalog.json file",
        required=False,
    )
    return parser


def setup_logger(debug):
    # Create handlers
    stdout_handler = logging.StreamHandler(sys.stdout)
    stderr_handler = logging.StreamHandler(sys.stderr)

    # Set levels
    stdout_handler.setLevel(logging.DEBUG)
    stderr_handler.setLevel(logging.ERROR)

    # Create formatters and add them to the handlers
    formatter = logging.Formatter("%(levelname)s: %(message)s")
    stdout_handler.setFormatter(formatter)
    stderr_handler.setFormatter(formatter)

    # Add handlers to the logger
    logger.addHandler(stdout_handler)
    logger.addHandler(stderr_handler)

    # switch log level to DEBUG if passed as argument
    if debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(level=logging.INFO)


def validate_catalog_json_input(catalog_json):
    if not os.path.exists(catalog_json):
        logger.error(f"ibm_catalog.json file {catalog_json} not found")
        exit(1)


def get_apikey(apikey_arg):
    if apikey_arg:
        apikey = apikey_arg
    else:
        apikey = os.environ.get("IBM_CLOUD_API_KEY")

    if not apikey:
        logger.error(
            "IBM_CLOUD_API_KEY environment variable not set or passed as argument"
        )
        exit(1)
    return apikey


def update_da_dependency_versions(service, original_ibm_catalog_json):
    ibm_catalog_json = copy.deepcopy(original_ibm_catalog_json)
    for flavor in ibm_catalog_json["products"][0]["flavors"]:
        if "dependencies" not in flavor:
            logger.info(f"Flavor {flavor['name']} does not have any dependencies")
            continue
        for dependency in flavor["dependencies"]:
            catalog_id = dependency["catalog_id"]
            offering_id = dependency["id"]
            offering_name = dependency["name"]
            current_version = dependency["version"]
            offering_flavor = dependency["flavors"][0]
            logger.info(
                f"{offering_name} {offering_flavor} current version: {current_version}"
            )
            response = service.get_offering(
                catalog_identifier=catalog_id, offering_id=offering_id, digest=True
            ).get_result()
            versions = []
            for version in response["kinds"][0]["versions"]:
                if (
                    version["flavor"]["name"] == offering_flavor
                    and version["is_consumable"]
                ):
                    versions.append(version["version"])
            latest_version = newest_version(versions)
            if dependency["version"] != latest_version:
                logger.info(
                    f"Updating {offering_name} {offering_flavor} to latest version: {latest_version}\n"
                )
                dependency["version"] = latest_version
            else:
                logger.info(
                    f"No change required for {offering_name} {offering_flavor} on version: {current_version}\n"
                )
    return ibm_catalog_json


def update_ibmcatalog_json_file(apikey, catalog_json_file):
    authenticator = IAMAuthenticator(apikey)
    service = CatalogManagementV1(authenticator=authenticator)
    with open(catalog_json_file, "r") as f:
        ibm_catalog_json = json.loads(f.read())
        logger.info(
            f"Updating dependencies for product {ibm_catalog_json['products'][0]['name']}"
        )
        logger.info("=================================================================")
        updated_json = update_da_dependency_versions(service, ibm_catalog_json)
    if args.dry_run:
        logger.info(f"Run in DRY_RUN mode, No update made to {catalog_json_file}")
    else:
        if updated_json != ibm_catalog_json:
            with open(
                catalog_json_file, "w", encoding="utf-8"
            ) as f:  # replace in place
                f.write(json.dumps(updated_json, ensure_ascii=False, indent=2) + "\n")
        else:
            logger.info(f"No update made to {catalog_json_file}")


if __name__ == "__main__":
    args = intialize_parser().parse_args()
    setup_logger(args.debug)

    validate_catalog_json_input(args.catalog_json)
    apikey = get_apikey(args.apikey)

    update_ibmcatalog_json_file(apikey, args.catalog_json)
