#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import os
import time
from typing import Dict, List, Tuple

from common.exceptions import (
    ApprovalError,
    ConfigNotFoundError,
    DeploymentError,
    ProjectNotFoundError,
    StackNotFoundError,
    ValidationError,
)
from common.helper import (  # set_authorization,
    check_require_tools,
    find_dict_with_key,
    is_logged_in,
    login_ibmcloud,
    parse_time,
    run_command,
    string_to_state,
    string_to_state_code,
)
from common.logger import get_logger, setup_logger
from constants import common_constants as const
from constants import messages as logmsg
from constants.common_constants import State, StateCode

error_occurred = False  # Flag to mark if error occurred during project deployment


def add_cli_arguments(parser) -> None:
    parser.add_argument(
        "-p", "--project_name", type=str, help="The project name", default=None
    )
    parser.add_argument(
        "-s", "--stack_name", type=str, help="The stack name", default=None
    )
    parser.add_argument(
        "-o",
        "--config_order",
        type=str,
        default=None,
        help='The config names in order to be deployed in the format "config1|config2|config3"',
    )
    parser.add_argument(
        "--stack_def_path",
        type=str,
        help="The path to the stack definition json file",
        default="stack_definition.json",
    )
    # alternatively, config from json file
    parser.add_argument(
        "-c",
        "--config_json_path",
        type=str,
        default=None,
        help="The path to the config json file",
    )
    parser.add_argument(
        "-u", "--undeploy", action="store_true", help="Undeploy the stack"
    )
    parser.add_argument(
        "--stack_inputs",
        type=str,
        help='Stack inputs as json string {"inputs":{"input1":"value1", "input2":"value2"}}',
        default=None,
    )
    parser.add_argument(
        "--stack_api_key_env",
        type=str,
        help="The environment variable name for the stack api key",
        default="IBMCLOUD_API_KEY",
    )
    parser.add_argument(
        "--skip_stack_inputs", action="store_true", help="Skip setting stack inputs"
    )
    parser.add_argument(
        "--stack_definition_update",
        action="store_true",
        help="Updating stack definition",
    )
    parser.add_argument(
        "--parallel", action="store_true", help="Deploy configurations in parallel"
    )
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")


def parse_params() -> Tuple[str, str, List[str], str, str, str, bool, bool, bool, bool]:
    """
    Parse command line parameters.
    Returns:
        Tuple containing:
            project name, stack name, config order,
            stack definition path, stack inputs, api key environment variable name,
            undeploy flag, skip stack inputs flag, stack definition update flag, debug flag
    """
    parser = argparse.ArgumentParser(
        description="Update and deploy stack, or undeploy. Arguments override config "
        "json file."
    )
    add_cli_arguments(parser)
    args = parser.parse_args()
    project_name = args.project_name
    stack_name = args.stack_name
    stack_inputs = None

    if args.stack_inputs:
        try:
            stack_inputs = json.loads(args.stack_inputs)
        except json.JSONDecodeError:
            get_logger().error("Invalid stack inputs json")
            exit(1)

    config_order = args.config_order
    if config_order:
        config_order = config_order.split("|")

    debug = args.debug
    stack_def_path = args.stack_def_path
    api_key_env = None
    # load config from json file
    # { "project_name": "project_name", "stack_name": "stack_name", "config_order": ["config1", "config2"] }
    if not args.config_json_path:
        if os.environ.get(api_key_env) is None:
            get_logger().error("Environment variable `stack_api_key_env` must be set")
            exit(1)
    else:
        try:
            with open(args.config_json_path) as f:
                config = json.load(f)
        except FileNotFoundError:
            get_logger().error(
                f"Config json file not found at: {args.config_json_path}"
            )
            exit(1)
        except json.JSONDecodeError:
            get_logger().error(f"Invalid config json: {args.config_json_path}")
            exit(1)
        # Read values from config file.
        stack_def_path = config.get("stack_def_path", stack_def_path)
        api_key_env = config.get("stack_api_key_env", api_key_env)

        if not project_name:
            project_name = config.get("project_name", "")

        if not stack_name:
            stack_name = config.get("stack_name", "")

        if not stack_inputs:
            stack_inputs = config.get("stack_inputs", "")

        # if config_order is not provided, use the config_order from the config file, only if not in parralel
        if (not config_order or args.undeploy) and not args.parallel:
            config_order = config.get("config_order", [])

    if not api_key_env:
        api_key_env = args.stack_api_key_env

    # check stack_def_path exists
    if not stack_def_path or not os.path.exists(stack_def_path):
        get_logger().error("Stack definition path must be provided and exist\n")
        # print argument help
        parser.print_help()
        exit(1)

    # error if project name, stack name or config name pattern is not provided
    if not project_name or not stack_name:
        get_logger().error("Project name, stack name and config order must be provided")
        # print argument help
        parser.print_help()
        exit(1)

    return (
        project_name,
        stack_name,
        config_order,
        stack_def_path,
        stack_inputs,
        api_key_env,
        args.undeploy,
        args.skip_stack_inputs,
        args.stack_definition_update,
        args.parallel,
        debug,
    )


def get_project_id(project_name: str) -> str:
    """
    Get project ID.
    Args:
        project_name (str): Project name.
    Returns:
        str: Project ID.
    """
    command = "ibmcloud project list --all-pages --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Project list: {output}")
    data = json.loads(output)
    projects = data.get("projects", [])
    for project in projects:
        # Check if 'metadata' exists in the project dictionary
        if "definition" in project and project["definition"]["name"] == project_name:
            get_logger().debug(f'Project ID for {project_name} found: {project["id"]}')
            return project["id"]
    raise ProjectNotFoundError(f"Project {project_name} not found")


def get_project_configs(project_id: str) -> list[dict]:
    """
    Get project configs.
    Args:
        project_id (str): Project ID.
    Returns:
        list[dict]: List of project configs.
    """
    command = (
        f"ibmcloud project configs --project-id {project_id} --all-pages --output json"
    )
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Project configs: {output}")
    data = json.loads(output)
    return data.get("configs", [])


def get_stack_id(project_id: str, stack_name: str) -> str:
    """
    Get stack ID.
    Args:
        project_id (str): Project ID.
        stack_name (str): Stack name.
    Returns:
        str: Stack ID.
    """
    project_configs = get_project_configs(project_id)
    for config in project_configs:
        if "definition" in config and config["definition"]["name"] == stack_name:
            get_logger().debug(f'Stack ID for {stack_name} found: {config["id"]}')
            return config["id"]
    raise StackNotFoundError(f"Stack {stack_name} not found")


def get_config_ids_for_stack(project_id: str, stack_name: str) -> List[Dict]:
    """
    Get config IDs for a stack.
    Args:
        project_id (str): Project ID.
        stack_name (str): Stack name.
    Returns:
        list[dict]: List of config IDs for the stack.
    """
    # config_ids  =  [{'config1': {'locator_id': '12345.1234', 'catalog_id':'12345', 'config_id': '1234'}}]
    config_ids = []
    stack_id = get_stack_id(project_id, stack_name)
    command = f"ibmcloud project config --project-id {project_id}  --id {stack_id} --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Project configs: {output}")
    data = json.loads(output)

    members = data.get("definition", {}).get("members", [])
    # get list of config_id for each member
    for member in members:
        config_ids.append({member["name"]: {"config_id": member["config_id"]}})
    return config_ids


def get_config_ids(
    project_id: str, stack_name: str, config_order: List[str]
) -> List[Dict]:
    """
    Get config IDs.
    Args:
        project_id (str): Project ID.
        stack_name (str): Stack name.
        config_order (list[str]): Config order.
    Returns:
        list[dict]: List of config IDs.
    """
    project_configs = get_project_configs(project_id)
    configs = []
    for config in project_configs:
        # ignore if stack
        if config["deployment_model"] == "stack":
            get_logger().debug(f"Skipping stack:\n{config}")
            continue
        get_logger().debug(f"Checking Config:\n{config}")
        # Check if 'definition' exists in the config dictionary
        # when deploying from tile the config name is in the format stack_name-config_name so strip the prefix
        stripped_stack_name = ""
        # Check if 'definition' exists in the config dictionary
        if "definition" in config:
            # Define the possible prefixes
            prefixes = [f"{stack_name}-", f"{stack_name} -"]

            # Initialize stripped_stack_name with the original name
            stripped_stack_name = config["definition"]["name"]

            # Iterate over the prefixes
            for prefix in prefixes:
                # If the name starts with the current prefix, strip it
                if stripped_stack_name.startswith(prefix):
                    stripped_stack_name = stripped_stack_name[len(prefix) :]
                    # Once a prefix is found and stripped, no need to check for other prefixes
                    break

        if stripped_stack_name in config_order:
            cur_config = {
                config["definition"]["name"]: {
                    "locator_id": config["definition"]["locator_id"],
                    "config_id": config["id"],
                }
            }
            # only add unique configs
            if cur_config not in configs:
                configs.append(cur_config)
    if len(configs) != len(config_order):
        # show missing configs
        for config in config_order:
            if config not in configs and f"{stack_name}-{config}" not in configs:
                get_logger().error(f"Config {config} not found")
        if len(configs) < len(config_order):
            get_logger().error(
                f"Not all configs found, expected: {config_order}\nFound: {configs}"
            )
        if len(configs) > len(config_order):
            get_logger().error(
                f"Too many configs found, expected: {config_order}\nFound: {configs}"
            )
        raise ConfigNotFoundError("Config not found")

    # sort configs based on config_order, the stack name may be included in the config name
    sorted_confs = []
    # configs  =  [{'config1': {'locator_id': '12345.1234', 'catalog_id':'12345', 'config_id': '1234'}}]
    for conf in config_order:
        if conf not in configs:
            # assume the config name is in the format stack_name-config_name
            conf = f"{stack_name}-{conf}"
        sorted_confs.append(find_dict_with_key(configs, conf))
    get_logger().debug(f"Config IDs: {sorted_confs}")
    return sorted_confs


def update_stack_definition(
    project_id: str, stack_id: str, stack_def_path: str
) -> None:
    """
    Update stack definition.
    Args:
        project_id (str): Project ID.
        stack_id (str): Stack ID.
        stack_def_path (str): Stack definition path.
    """

    command = (
        f"ibmcloud project config-update --project-id {project_id} "
        f"--id {stack_id} --definition @{stack_def_path}"
    )
    output, err = run_command(command)
    if err:
        get_logger().error(f"Error: {err}")
        exit(1)
    get_logger().debug(f"Stack definition updated: {output}")


def set_stack_inputs(
    project_id: str, stack_id: str, stack_inputs: dict, api_key_env: str
) -> None:
    """
    Set stack inputs.
    Args:
        project_id (str): Project ID.
        stack_id (str): Stack ID.
        stack_inputs (dict): Stack inputs.
        api_key_env (str): API key environment variable name.
    """
    # if input dict key has value API_KEY replace with the value from the environment variable
    for key, value in stack_inputs.items():
        if value == "API_KEY":
            stack_inputs[key] = os.environ.get(api_key_env)

    stack_input_json = json.dumps(stack_inputs)
    command = (
        f"ibmcloud project config-update --project-id {project_id} "
        f"--id {stack_id} --definition-inputs '{stack_input_json}'"
    )
    output, err = run_command(command)
    if err:
        get_logger().error(f"Error: {err}")
        exit(1)
    get_logger().debug(f"Stack inputs updated: {output}")


def validate_config(project_id: str, config_id: str, timeout: str = "30m") -> None:
    """
    Validate config.
    Args:
        project_id (str): Project ID.
        config_id (str): Config ID.
        timeout (str): Timeout for validation.
    """
    start_time = time.time()
    end_time = start_time + parse_time(timeout)
    state = get_config_state(project_id, config_id)
    config_name = get_config_name(project_id, config_id)

    if state in const.VALIDATION_STATES:
        get_logger().info(f"[{config_name}] Already Validated Skipping: {config_id}")
        return

    if state != State.VALIDATED:
        command = f"ibmcloud project config-validate --project-id {project_id} --id {config_id}"
        _, err = run_command(command)
        if err:
            raise Exception(f"Error: {err}")

        get_logger().info(f"[{config_name}] Started validation for config {config_id}")
        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Check if we really need this again?
        while state == State.VALIDATING and time.time() < end_time:
            time.sleep(30)
            state = get_config_state(project_id, config_id)
            get_logger().info(f"[{config_name}] Validating {config_id}...")
            get_logger().debug(f"[{config_name}] Validation state: {state}")

        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Check if we really need this again?
        if state != State.VALIDATED:
            raise ValidationError(
                f"[{config_name}] Validation failed for config {config_id}"
            )
    get_logger().debug(f"[{config_name}] Config validated successfully: {config_id}")


def get_config_state(project_id: str, config_id: str) -> State:
    """
    Get the state of a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    Returns:
        The state of the config.
    """
    command = f"ibmcloud project config --project-id {project_id} --id {config_id} --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Config state: {output}")
    data = json.loads(output)
    state = data.get("state", "")
    if state == "":
        get_logger().error(f"state not found for config {config_id}\n{data}")
        return State.UNKNOWN
    return string_to_state(state)


def get_config_state_code(project_id: str, config_id: str) -> StateCode:
    """
    Get the state code of a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    Returns:
        The state code of the config.
    """
    command = f"ibmcloud project config --project-id {project_id} --id {config_id} --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Config state: {output}")
    data = json.loads(output)
    state_code = data.get("state_code", "")
    if state_code == "":
        return StateCode.UNKNOWN
    return string_to_state_code(state_code)


def get_config_name(project_id: str, config_id: str) -> str:
    """
    Get the name of a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    Returns:
        The name of the config.
    """
    command = f"ibmcloud project config --project-id {project_id} --id {config_id} --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Config name: {output}")
    data = json.loads(output)
    name = data.get("definition", {}).get("name", "UNKNOWN")
    return name


def get_config_deployed_state(project_id: str, config_id: str) -> State:
    """
    Get the deployed state of a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    Returns:
        The deployed state of the config.
    """
    command = f"ibmcloud project config --project-id {project_id} --id {config_id} --output json"
    output, err = run_command(command)
    if err:
        raise Exception(f"Error: {err}")
    get_logger().debug(f"Config deployed: {output}")
    data = json.loads(output)
    state = data.get("deployed_version", {}).get("state", "")
    if state == "":
        # if not deployed get the current config state instead
        return get_config_state(project_id, config_id)
    return string_to_state(state)


def approve_config(project_id: str, config_id: str) -> None:
    """
    Approve a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    """

    try:
        state = get_config_state(project_id, config_id)
        config_name = get_config_name(project_id, config_id)
    except Exception as e:
        raise Exception(f"Error retrieving config state or name: {e}")

    if state in {State.DEPLOYED, State.DEPLOYING_FAILED}:
        get_logger().info(f"[{config_name}] Already Approved Skipping: {config_id}")
        return

    # only approve if not already approved and validated
    if state != State.APPROVED and state == State.VALIDATED:
        get_logger().info(f"[{config_name}] Approving config: {config_id}")
        command = (
            f"ibmcloud project config-approve --project-id {project_id} "
            f'--id {config_id} --comment "Approved by script"'
        )
        _, err = run_command(command)
        if err:
            raise ApprovalError(
                f"[{config_name}] Error approving config {config_id}, error: {err}"
            )
        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Do we really need it again?
        start_time = time.time()
        end_time = start_time + parse_time("5m")

        while state != State.APPROVED and time.time() < end_time:
            time.sleep(5)
            state = get_config_state(project_id, config_id)
            get_logger().info(f"[{config_name}] Approving {config_id}...")
            get_logger().debug(f"[{config_name}] Approve {config_id} state: {state}")

        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Do we really need it again?

        if state != State.APPROVED:
            raise ApprovalError(
                f"[{config_name}] Approval failed for config {config_id}"
            )
        get_logger().info(f"[{config_name}] Config Approved: {config_id}")

    elif state == State.APPROVED:
        get_logger().info(f"[{config_name}] Already Approved Skipping: {config_id}")

    elif state != State.VALIDATED:
        raise ApprovalError(
            f"[{config_name}] "
            f"Config not validated: {config_id} cannot be approved, current state: {state}"
        )

    # TODO: PRATEEK - CHECK WHY WE HAVE REDUNDANT CODE AT SO MANY PLACES!
    state = get_config_state(project_id, config_id)
    if state != State.APPROVED:
        raise ApprovalError(
            f"Approval failed for config {config_id}, current state: {state}"
        )


def deploy_config(project_id: str, config_id: str, timeout: str = "2h") -> None:
    """
    Deploy a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    """

    start_time = time.time()
    end_time = start_time + parse_time(timeout)

    try:
        state = get_config_state(project_id, config_id)
        config_name = get_config_name(project_id, config_id)
    except Exception as e:
        raise DeploymentError(f"Error retrieving config state or name: {e}")

    if state in {State.APPROVED, State.DEPLOYING_FAILED}:
        get_logger().info(f"[{config_name}] Deploying config: {config_id}")
        command = (
            f"ibmcloud project config-deploy --project-id {project_id} --id {config_id}"
        )
        _, err = run_command(command)
        if err:
            raise DeploymentError(f"[{config_name}] Error deploying config {config_id}")

        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Redundant call?
        while state == State.DEPLOYING and time.time() < end_time:
            time.sleep(30)
            state = get_config_state(project_id, config_id)
            get_logger().info(f"[{config_name}] Deploying {config_id}...")
            get_logger().debug(f"[{config_name}] Deploy {config_id} state: {state}")

        state = get_config_state(
            project_id, config_id
        )  # TODO: PRATEEK - Redundant call?

        if state != State.DEPLOYED:
            # TODO: lookup deployment failure reason
            raise DeploymentError(
                f"[{config_name}] Deployment failed for config {config_id}"
            )
        get_logger().info(f"[{config_name}] Config Deployed: {config_id}")

    elif state == State.DEPLOYED:
        get_logger().info(f"[{config_name}] Already Deployed Skipping: {config_id}")
        return

    elif state != State.APPROVED:
        raise DeploymentError(
            f"[{config_name}] Config not approved: "
            f"{config_id} cannot be deployed, current state: {state}"
        )

    else:
        raise DeploymentError(
            f"[{config_name}] Config not in a state that can be deployed: "
            f"{config_id}, current state: {state}"
        )


def undeploy_config(project_id: str, config_id: str, timeout: str = "2h") -> None:
    """
    Undeploy a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    """

    start_time = time.time()
    end_time = start_time + parse_time(timeout)

    config_name = get_config_name(project_id, config_id)
    state = get_config_deployed_state(project_id, config_id)

    if state in const.DEPLOYABLE_STATES:
        if state != State.UNDEPLOYING:
            get_logger().info(f"[{config_name}] Undeploying config: {config_id}")
            command = f"ibmcloud project config-undeploy --project-id {project_id} --id {config_id}"
            _, err = run_command(command)
            if err:
                raise DeploymentError(
                    f"[{config_name}] Error undeploying config {config_id}"
                )
        state = get_config_deployed_state(
            project_id, config_id
        )  # TODO: PRATEEK - THIS IS NOT REQUIRED
        while state == State.UNDEPLOYING and time.time() < end_time:
            time.sleep(30)
            state = get_config_deployed_state(project_id, config_id)
            get_logger().info(f"[{config_name}] Undeploying {config_id}...")
            get_logger().debug(f"[{config_name}] Undeploy {config_id} state: {state}")

        state = get_config_deployed_state(
            project_id, config_id
        )  # TODO: PRATEEK CHECK WHY AGAIN IT IS NEEDED?
        if state in {State.DEPLOYED, State.UNDEPLOYING_FAILED}:
            raise DeploymentError(
                f"[{config_name}] Undeployment failed for config {config_id}"
            )
        get_logger().info(f"[{config_name}] Config undeployed: {config_id}")
    else:
        get_logger().info(
            f"[{config_name}] Config not deployed: {config_id} skipping undeploy, current state: {state}"
        )


def validate_approve_and_deploy(project_id: str, config_id: str) -> None:
    """
    Validate and deploy a config.
    Args:
        project_id: The project ID.
        config_id: The config ID.
    """
    try:
        validate_config(project_id, config_id)
        approve_config(project_id, config_id)
        deploy_config(project_id, config_id)
    except ValidationError as verr:
        get_logger().error(f"Validation error: {verr}")
        raise verr
    except ApprovalError as aerr:
        get_logger().error(f"Approval error: {aerr}")
        raise aerr
    except DeploymentError as derr:
        get_logger().error(f"Deployment error: {derr}")
        raise derr
    except Exception as e:
        get_logger().error(f"Error occurred during validation and deployment: {e}")
        raise e


def initiate_parallel_execution(config_ids, project_id, error_messages):
    global error_occurred

    def can_deploy(config):
        try:
            config_id = list(config.values())[0]["config_id"]
            config_name = get_config_name(project_id, config_id)
            current_state = get_config_state(project_id, config_id)
            current_state_code = get_config_state_code(project_id, config_id)

            if current_state_code == StateCode.AWAITING_PREREQUISITE:
                get_logger().info(
                    f"Config {config_name} ID: {config_id} has a prerequisite and cannot be validated or deployed"
                )
                return False

            if current_state == State.DEPLOYED:
                config_ids.remove(config)
                return False

            get_logger().info(
                f"Checking for config {config_name} ID: {list(config.values())[0]['config_id']} "
                f"ready for validation and deployment"
            )

            if (
                current_state_code == StateCode.AWAITING_VALIDATION
                and current_state == State.DRAFT
            ) or current_state in const.READY_STATE:
                get_logger().info(
                    f"Config {config_name} ID: {config_id} is ready for validation and deployment, current state: {current_state}"
                )
                return True
            else:
                get_logger().info(
                    f"Config {config_name} ID: {config_id} is not ready for validation and deployment, current state: {current_state}"
                )
                return False

        except Exception as err:
            get_logger().info(
                f"Config {config_name} ID: {config_id} no state found, trying to validate and deploy.\nException: {err}"
            )
            return True

    while config_ids and not error_occurred:
        ready_to_deploy = [config for config in config_ids if can_deploy(config)]

        if ready_to_deploy:
            get_logger().info(
                f"Configs ready for validation and deployment: {ready_to_deploy}"
            )
            deploy_configs_parallel(ready_to_deploy, project_id, error_messages)
        else:
            get_logger().info("No configs ready for validation and deployment")


def deploy_configs_parallel(configs, project_id, error_messages):
    global error_occurred
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = []
        for config in configs:
            try:
                config_id = list(config.values())[0]["config_id"]
                futures.append(
                    executor.submit(
                        validate_approve_and_deploy,
                        project_id,
                        config_id,
                    )
                )
            except (IndexError, KeyError) as err:
                get_logger().error(
                    f"{const.PDE}\nInvalid configuration format: {config} - Exception: {err}"
                )
                error_messages.append(
                    f"Invalid configuration format: {config} - Exception: {err}"
                )
                error_occurred = True
                break
            except (ValidationError, ApprovalError, DeploymentError) as err:
                get_logger().error(
                    f"{const.PDE}\nValidation/Approval/Deployment error: \n{err}"
                )
                error_messages.append(str(err))
                error_occurred = True
                break
            except Exception as e:
                get_logger().error(
                    f"{const.PDE}\nError occurred during validation and deployment: {e}"
                )
                error_messages.append(str(e))
                error_occurred = True
                break

        if not error_occurred:
            concurrent.futures.wait(futures)  # wait for all futures to complete
            for future in futures:
                if future.exception() is not None:
                    get_logger().error(
                        logmsg.ERR_FUTURE_EXCPN.format(future.exception())
                    )
                    error_messages.append(str(future.exception()))
                    error_occurred = True
                    break


def sequential_deployment(config_ids, project_id, error_messages):
    for config in config_ids:
        try:
            validate_approve_and_deploy(
                project_id, list(config.values())[0]["config_id"]
            )
        except ValidationError as verr:
            get_logger().error(f"Validation error: {verr}")
            error_messages.append(str(verr))
            break
        except ApprovalError as aerr:
            get_logger().error(f"Approval error: {aerr}")
            error_messages.append(str(aerr))
            break
        except DeploymentError as derr:
            get_logger().error(f"Deployment error: {derr}")
            error_messages.append(str(derr))
            break
        except Exception as e:
            get_logger().error(f"Error occurred during validation and deployment: {e}")
            error_messages.append(str(e))
            break


def main() -> None:
    """
    Main function.
    """
    (
        project_name,
        stack_name,
        config_order,
        stack_def_path,
        stack_inputs,
        api_key_env,
        undeploy,
        skip_stack_inputs,
        stack_def_update,
        parallel,
        debug,
    ) = parse_params()

    if debug:
        setup_logger("DEBUG")

    log_info = {
        "Project name": project_name,
        "Stack name": stack_name,
        "API key environment variable": "***MASKED***",
        "Config order": config_order,
        "Stack definition path": stack_def_path,
        "Undeploy": undeploy,
        "Skip stack inputs": skip_stack_inputs,
        "Stack definition update": stack_def_update,
        "Deploy in Parallel": parallel,
        "Debug": debug,
    }
    for key, value in log_info.items():
        get_logger().info(f"{key}: {value}")

    get_logger().debug("\nStack inputs:\n")
    for k, v in stack_inputs.items():
        get_logger().debug(f"{k}: ***MASKED***" if "_key" in k.lower() else f"{k}: {v}")

    missing = check_require_tools()

    if missing["tools"]:
        get_logger().error(logmsg.ERR_NO_TOOLS.format(missing["tools"]))
        exit(1)

    if missing["plugins"]:
        get_logger().error(logmsg.ERR_NO_PLUGINS.format(missing["plugins"]))
        exit(1)

    if not is_logged_in():
        login_ibmcloud(api_key_env)

    # Create a list to store error messages
    error_messages = []
    project_id = get_project_id(project_name)
    # TODO: support multiple stacks
    stack_id = get_stack_id(project_id, stack_name)
    # config_ids = get_config_ids(project_id, stack_name, config_order)
    config_ids = get_config_ids_for_stack(project_id, stack_name)
    if undeploy:
        # undeploy all configs in reverse order
        for config in reversed(config_ids):
            try:
                undeploy_config(project_id, list(config.values())[0]["config_id"])
            except DeploymentError as derr:
                get_logger().error(f"Un-deployment error: {derr}")
                error_messages.append(str(derr))
    else:
        if stack_def_update:
            get_logger().info(f"Updating stack definition for stack {stack_name}")
            update_stack_definition(project_id, stack_id, stack_def_path)
        if not skip_stack_inputs and stack_inputs:
            #  TODO: check if this is needed
            # get_logger().info(f'Setting authorization for stack {stack_name}')
            # set_authorization(project_id, stack_id, api_key_env)
            get_logger().info(f"Setting stack inputs for stack {stack_name}")
            set_stack_inputs(project_id, stack_id, stack_inputs, api_key_env)

        if parallel:
            initiate_parallel_execution(config_ids, project_id, error_messages)
        else:
            sequential_deployment(config_ids, project_id, error_messages)

    # At the end of the script, print the error messages if any
    if error_messages:
        get_logger().info(logmsg.MSG_LIST_ERRS)
        for msg in error_messages:
            get_logger().error(msg)


if __name__ == "__main__":
    main()
