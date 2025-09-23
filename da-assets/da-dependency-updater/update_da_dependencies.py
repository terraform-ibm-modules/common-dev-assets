import argparse
import copy
import json
import logging
import os
import sys

import requests
import semver
from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
from ibm_platform_services.catalog_management_v1 import CatalogManagementV1

# Get the root logger
logger = logging.getLogger()


def initialize_parser():
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


def get_tokens(api_key: str):
    try:
        iam_url = "https://iam.cloud.ibm.com/identity/token"
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        data = {
            "grant_type": "urn:ibm:params:oauth:grant-type:apikey",
            "apikey": api_key,
        }

        response = requests.post(iam_url, headers=headers, data=data)
        logger.debug(response)
        response_json = response.json()

        return response_json.get("access_token"), response_json.get("refresh_token")
    except Exception as e:
        logger.error(f"Error getting tokens: {str(e)}")
        return None, None


def get_version_updates(offeringId, catalogId, kind, flavor, api_key):
    authenticator = IAMAuthenticator(api_key)
    service = CatalogManagementV1(authenticator=authenticator)
    _, refresh_token = get_tokens(api_key)
    try:
        response = service.get_offering_updates(
            catalog_identifier=catalogId,
            offering_id=offeringId,
            kind=kind,
            x_auth_refresh_token=refresh_token,
        ).get_result()
        logger.debug(f"Got updates for {offeringId}")
        # filter updates by flavor name
        response = [
            update
            for update in response
            if "flavor" in update.keys() and update["flavor"]["name"] == flavor
        ]
        logger.debug(f"Number of filtered updates: {len(response)}")
        return response
    except KeyError as e:
        logger.error(
            f"KeyError: {str(e)} in update dictionary. Please ensure the update dictionary has the correct "
            f"structure."
        )
        return None
    except Exception as e:
        logger.error(f"Error getting version updates for {offeringId}: {str(e)}")
        return None


def get_latest_valid_version(updates):
    try:
        # sort updates by version
        updates = sorted(
            updates,
            key=lambda x: semver.VersionInfo.parse(x["version"].lstrip("v")),
            reverse=True,
        )
        logger.debug(f"Number of sorted updates: {len(updates)}")
        # get the latest version that is not deprecated, consumable and not a pre-release version
        for update in updates:
            try:
                version_info = semver.VersionInfo.parse(update["version"].lstrip("v"))
                logger.debug(f"Checking update: {update}")
                if (
                    update["can_update"]
                    and update["state"]["current"] == "consumable"
                    and version_info.prerelease is None
                ):
                    logger.debug(f"Selected latest valid version: {update['version']}")
                    return update
            except ValueError:
                logger.debug(f"Skipping invalid version format: {update['version']}")
                continue
        return None
    except Exception as e:
        logger.error(f"Error getting latest valid version: {str(e)}")
        return None


def update_da_dependency_versions(apikey, original_ibm_catalog_json):
    ibm_catalog_json = copy.deepcopy(original_ibm_catalog_json)
    for product in ibm_catalog_json["products"]:
        for flavor in product["flavors"]:
            if flavor.get("install_type") == "extension":
                logger.info(
                    f"Flavor {flavor['name']} has install type `extension`, skipping."
                )
                continue
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
                updates = get_version_updates(
                    offering_id, catalog_id, "terraform", offering_flavor, apikey
                )
                if updates is None:
                    logger.error(f"Failed to get versions for {offering_id}\n")
                    continue
                latest_version = get_latest_valid_version(updates)["version"]
                if latest_version is None:
                    logger.error(f"Failed to get latest valid version for {updates}\n")
                    continue
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
    with open(catalog_json_file) as f:
        ibm_catalog_json = json.loads(f.read())
        logger.info(
            f"Updating dependencies for product {ibm_catalog_json['products'][0]['name']}"
        )
        logger.info("=================================================================")
        updated_json = update_da_dependency_versions(apikey, ibm_catalog_json)
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
    args = initialize_parser().parse_args()
    setup_logger(args.debug)

    validate_catalog_json_input(args.catalog_json)
    apikey = get_apikey(args.apikey)

    update_ibmcatalog_json_file(apikey, args.catalog_json)
