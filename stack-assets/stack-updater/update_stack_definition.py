import argparse
import json
import logging
import os
import sys
from typing import Any, Dict, List

import requests
import semver
from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
from ibm_platform_services.catalog_management_v1 import CatalogManagementV1

# Get the root logger
logger = logging.getLogger()


def get_tokens(api_key: str) -> (str, str):
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


def get_version(locator_id: str, api_key: str):
    authenticator = IAMAuthenticator(api_key)
    service = CatalogManagementV1(authenticator=authenticator)
    try:
        response = service.get_version(version_loc_id=locator_id).get_result()
        logger.debug(f"Got version {locator_id}: {response.get('id', 'N/A')}")
        return response
    except Exception as e:
        logger.error(f"Error getting version {locator_id}: {str(e)}")
        return None


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


def get_latest_valid_version(updates: List[Dict[str, Any]]):
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


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Update Stack Memeber Versions")
    parser.add_argument(
        "--stack",
        "-s",
        type=str,
        action="store",
        dest="stack",
        help="path stack definition json",
        required=True,
    )
    parser.add_argument(
        "--api-key",
        "-k",
        type=str,
        action="store",
        dest="api_key",
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
        help="Dry run mode, do not update stack definition",
        required=False,
    )

    args = parser.parse_args()

    # if api key passed as argument, use it or else use the environment variable, error if not set
    if args.api_key:
        api_key = args.api_key
    else:
        api_key = os.environ.get("IBM_CLOUD_API_KEY")

    if not api_key:
        logger.error(
            "IBM_CLOUD_API_KEY environment variable not set or passed as argument"
        )
        # print argument help
        parser.print_help()
        exit(1)

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
    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(level=logging.INFO)

    # check if stack definition json file exists
    if not os.path.exists(args.stack):
        logger.error(f"Stack definition file {args.stack} not found")
        exit(1)

    catalogs = {}  # Cache catalogs to avoid multiple requests
    failures = []  # List to track failures

    # read stack definition json
    with open(args.stack, "r") as f:
        stack_json = f.read()
        stack = json.loads(stack_json)
        logger.debug(f"Stack definition: {stack}")
        updates_made = False
        #     loop through each stack member
        for member in stack["members"]:
            try:
                logger.info(f"Updating {member['name']}")
                # split locator on . first part is the catalog id second is the version id
                version_locator = member["version_locator"]
                catalogId, versionId = version_locator.split(".")
                logger.debug(version_locator)
                version = get_version(version_locator, api_key)
                if version is None:
                    logger.error(
                        f"Failed to get version for {member['name']}: {version_locator}"
                    )
                    failures.append(
                        f"Failed to get version for {member['name']}: {version_locator}"
                    )
                    continue
                logger.debug(
                    f"current version: {version.get('kinds', [])[0].get('versions')[0].get('version')}"
                )
                kind = version.get("kinds", [])[0].get("format_kind")
                flavor = (
                    version.get("kinds", [])[0]
                    .get("versions")[0]
                    .get("flavor")
                    .get("name")
                )
                offeringId = version.get("id", {})
                updates = get_version_updates(
                    offeringId, catalogId, kind, flavor, api_key
                )
                if updates is None:
                    logger.error(f"Failed to get version updates for {offeringId}\n")
                    failures.append(f"Failed to get version updates for {offeringId}")
                    continue
                latest_version = get_latest_valid_version(updates)
                if latest_version is None:
                    logger.error(f"Failed to get latest valid version for {updates}\n")
                    failures.append(f"Failed to get latest valid version for {updates}")
                    continue
                latest_version_locator = latest_version.get("version_locator")
                latest_version_name = latest_version.get("version")
                current_version = (
                    version.get("kinds", [])[0].get("versions")[0].get("version")
                )
                logger.info(f"current version: {current_version}")
                logger.info(f"latest version: {latest_version_name}")
                logger.info(f"latest version locator: {latest_version_locator}")
                if current_version != latest_version_name:
                    current_version_info = semver.VersionInfo.parse(
                        current_version.lstrip("v")
                    )
                    latest_version_info = semver.VersionInfo.parse(
                        latest_version_name.lstrip("v")
                    )

                    if latest_version_info.major > current_version_info.major:
                        logger.warning("Major update detected!")

                    logger.info(
                        f"Updating {member['name']} to version {latest_version_name}\n"
                    )
                else:
                    logger.info(
                        f"{member['name']} is already up to date. No updates were made.\n"
                    )
                # check if the version locator has changed
                if member["version_locator"] != latest_version_locator:
                    # update stack member with latest version locator
                    member["version_locator"] = latest_version_locator
                    # set flag to True
                    updates_made = True

            except Exception as e:
                logger.error(f"Error updating member {member['name']}: {str(e)}\n")
                failures.append(f"Error updating member {member['name']}: {str(e)}")

    # write updated stack definition to file only if updates were made
    if updates_made:
        if args.dry_run:
            logger.info("Dry run mode, no updates were made to stack definition")
        else:
            with open(args.stack, "w") as f:
                f.write(json.dumps(stack, indent=2) + "\n")
            logger.info(f"Stack definition updated: {args.stack}")
    else:
        logger.info("Already up to date. No updates were made.")

    # Print summary of failures and exit with error code if any failures occurred
    if failures:
        failureString = "\n".join(failures)
        logger.error(f"\nSummary of failures:\n{failureString}")
        exit(1)
