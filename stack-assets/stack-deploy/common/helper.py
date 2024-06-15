import argparse
import json
import logging
import os
import subprocess
import time
from dataclasses import fields
from typing import Dict, List, Optional, Tuple

from constants import commands as cmd
from constants import common_constants as const


def string_to_state(state_str: str) -> const.State:
    try:
        return const.State[state_str.upper()]
    except KeyError:
        raise ValueError(f"Invalid state: {state_str}")


def string_to_state_code(state_code_str: str) -> const.StateCode:
    try:
        return const.StateCode[state_code_str.upper()]
    except KeyError:
        raise ValueError(f"Invalid state code: {state_code_str}")


def login_ibmcloud(api_key_env: str) -> None:
    """
    Login to IBM Cloud.
    Args:
        api_key_env (str): API key environment variable name.
    """
    command = cmd.LOGIN.format(
        api_key=os.environ.get(api_key_env), region="--no-region"
    )
    output, err = run_command(command)
    if err:
        logging.error(f"Error: {err}")
        exit(1)
    logging.debug(f"Login output: {output}")


def is_logged_in() -> bool:
    """
    Check if user is logged in.
    Returns:
        bool: True if user is logged in, False otherwise.
    """
    try:
        result, err = run_command(cmd.SHOW_ACCOUNT)
        logging.debug(f"Account show: {result}")
        if "Not logged in" in result or "Not logged in" in err:
            return False
        return True
    except subprocess.CalledProcessError:
        return False


def run_command(command: str) -> Tuple[str, str]:
    """
    Run a shell command.
    Args:
        command: The command to run.
    Returns:
        The stdout and stderr output of the command.
    """
    logging.debug(
        f"Running command: {command}"
    )  # TODO: PRATEEK - mask sensitive information

    for i in range(const.MAX_RETRY_COUNT):
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        output, error = process.communicate()
        # retry on tls handshake timeout
        if (
            "tls handshake timeout" in error.lower()
            or "tls handshake timeout" in output.lower()
        ):
            logging.error(
                f"Timeout error executing command {command}:\n"
                f"Output: {output}\nError:{error}\nretrying in 30 seconds, attempt {i + 1}/{const.MAX_RETRY_COUNT}"
            )
            time.sleep(30)
        elif process.returncode == 0:
            return output, error
        else:
            logging.error(f"error executing command: {command}")
            logging.error(f"Output: {output}\nError: {error}")
            return output, error


def check_require_tools() -> Dict:
    """
    Check required tools.
    Returns:
        dict: Missing tools and plugins.
    """
    tools = ["ibmcloud"]
    ibmcloud_plugins = ["project"]
    missing = {"tools": [], "plugins": []}  # use strings 'tools' and 'plugins' as keys
    for tool in tools:
        try:
            result = run_command(f"which {tool}")
            logging.debug(f"{tool} path: {result}")
        except FileNotFoundError:
            missing["tools"].append(tool)
    for plugin in ibmcloud_plugins:
        try:
            result = run_command(f"ibmcloud plugin show {plugin}")
            logging.debug(f"{plugin} plugin: {result}")
        except subprocess.CalledProcessError:
            missing["plugins"].append(plugin)

    return missing


def find_dict_with_key(list_of_dicts: List[Dict], key: str) -> Optional[Dict]:
    """
    Find the first dictionary in a list that contains a specified key.
    Args:
        list_of_dicts (list[dict]): The list of dictionaries to search.
        key (str): The key to search for.
    Returns:
        dict: The first dictionary that contains the key. If no dictionary contains the key, returns None.
    """
    for dictionary in list_of_dicts:
        if key in dictionary:
            return dictionary
    return None


def parse_time(time_str):
    """
    Parse a time string formatted as number followed by 's' for seconds, 'm' for minutes, 'h' for hours.
    Args:
        time_str (str): The time string to parse.
    Returns:
        int: The time in seconds.
    """

    if time_str.endswith("m"):
        parsed_time = int(time_str[:-1]) * 60
    elif time_str.endswith("h"):
        parsed_time = int(time_str[:-1]) * 3600
    elif time_str.endswith("s"):
        parsed_time = int(time_str[:-1]) * 1
    else:
        #     default to seconds
        try:
            parsed_time = int(time_str) * 1
        except ValueError:
            logging.error(f"Invalid time string: {time_str}")
            exit(1)
    return parsed_time


def set_authorization(project_id: str, stack_id: str, api_key_env: str) -> None:
    """
    Set authorization.
    Args:
        project_id (str): Project ID.
        stack_id (str): Stack ID.
        api_key_env (str): API key environment variable name.
    """
    auth_json = json.dumps(
        {"method": "api_key", "api_key": os.environ.get(api_key_env)}
    )
    command = (
        f"ibmcloud project config-update --project-id {project_id} "
        f"--id {stack_id} --definition-authorizations '{auth_json}'"
    )
    output, err = run_command(command)
    if err:
        logging.error(f"Error: {err}")
        exit(1)
    logging.debug("Authorization updated")


def add_cli_arguments(parser: argparse.ArgumentParser, config_class) -> None:
    for field in fields(config_class):
        field_args = field.metadata.get("args", [f'--{field.name.replace("_", "-")}'])
        field_type = field.type
        default_value = field.default
        help_text = field.metadata.get("help", "")
        action = field.metadata.get("action")

        if action:
            parser.add_argument(*field_args, action=action, help=help_text)
        else:
            parser.add_argument(
                *field_args,
                type=field_type if field_type != Optional[str] else str,
                default=default_value,
                help=help_text,
            )
